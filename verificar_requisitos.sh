#!/bin/bash

echo "======================================="
echo "   VERIFICAÇÃO DE REQUISITOS          "
echo "======================================="

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

DB_USER="drexys"
DB_NAME="drexys_db"

# 1. Verificar containers
echo -e "\n${YELLOW}1. Docker Compose com 4 containers:${NC}"
CONTAINERS=$(docker ps --format "{{.Names}}" | grep -E "nginx|backend|frontend|db" | wc -l)
if [ "$CONTAINERS" -eq 4 ]; then
    echo -e "${GREEN}✓ 4 containers rodando${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "nginx|backend|frontend|db"
else
    echo -e "${RED}✗ Apenas $CONTAINERS containers rodando${NC}"
fi

# 2. Verificar Nginx
echo -e "\n${YELLOW}2. Nginx servindo página:${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost)
if [ "$HTTP_CODE" -eq 200 ]; then
    echo -e "${GREEN}✓ Nginx respondendo (HTTP $HTTP_CODE)${NC}"
    echo "Conteúdo:"
    curl -s http://localhost | head -5
else
    echo -e "${RED}✗ Nginx não está respondendo corretamente (HTTP $HTTP_CODE)${NC}"
fi

# 3. Verificar Django Admin
echo -e "\n${YELLOW}3. Django Admin:${NC}"
ADMIN_CODE=$(curl -s -o /dev/null -w "%{http_code}" -L http://localhost/admin/)
if [ "$ADMIN_CODE" -eq 200 ] || [ "$ADMIN_CODE" -eq 302 ]; then
    echo -e "${GREEN}✓ Django admin acessível (HTTP $ADMIN_CODE)${NC}"
else
    echo -e "${RED}✗ Django admin não acessível (HTTP $ADMIN_CODE)${NC}"
fi

# 4. Verificar schemas PostgreSQL
echo -e "\n${YELLOW}4. Schemas PostgreSQL:${NC}"

SCHEMAS=$(docker exec drexys_db psql -U $DB_USER -d $DB_NAME -t -c \
  "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('clientes', 'ia_data');" 2>/dev/null | grep -E "clientes|ia_data" | wc -l)

if [ "$SCHEMAS" -eq 2 ]; then
    echo -e "${GREEN}✓ Schemas 'clientes' e 'ia_data' existem${NC}"
else
    echo -e "${RED}✗ Faltam schemas (encontrados: $SCHEMAS/2)${NC}"
    echo "Criando schemas..."
    docker exec drexys_db psql -U $DB_USER -d $DB_NAME -c \
      "CREATE SCHEMA IF NOT EXISTS clientes; CREATE SCHEMA IF NOT EXISTS ia_data;"

    sleep 1  # Aguarda um pouco antes de verificar novamente

    SCHEMAS=$(docker exec drexys_db psql -U $DB_USER -d $DB_NAME -t -c \
      "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('clientes', 'ia_data');" 2>/dev/null | grep -E "clientes|ia_data" | wc -l)

    if [ "$SCHEMAS" -eq 2 ]; then
        echo -e "${GREEN}✓ Schemas criados com sucesso${NC}"
    else
        echo -e "${RED}✗ Ainda faltam schemas após criação${NC}"
    fi
fi

# 5. Verificar comunicação entre containers
echo -e "\n${YELLOW}5. Comunicação entre containers:${NC}"
COMM_TEST=$(docker exec drexys_nginx curl -s -o /dev/null -w "%{http_code}" -H "Host: localhost" http://drexys_backend:8000)
if [ "$COMM_TEST" -ne 000 ]; then
    echo -e "${GREEN}✓ Comunicação funcionando (HTTP $COMM_TEST)${NC}"
else
    echo -e "${RED}✗ Problema na comunicação${NC}"
fi

echo -e "\n${YELLOW}RESUMO:${NC}"
echo "Para completar os requisitos, verifique:"
echo "1. Se o Nginx está servindo 'Hello World' em http://localhost"
echo "2. Se o Django admin está configurado e acessível"
echo "3. Se os schemas do PostgreSQL foram criados"
echo "4. Se o ALLOWED_HOSTS do Django inclui 'localhost'"
