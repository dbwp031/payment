#!/bin/bash
# ============================================
# Docker 기반 Flyway Migration 실행 스크립트
# Database: PostgreSQL 14
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# PostgreSQL 연결 정보
PG_URL="jdbc:postgresql://postgres:5432/payment_db"
PG_USER="payment"
PG_PASSWORD="payment123"

case "${1:-migrate}" in
    up)
        echo -e "${GREEN}Starting PostgreSQL...${NC}"
        docker-compose up -d postgres
        echo "Waiting for PostgreSQL to be ready..."
        sleep 5
        ;;
    migrate)
        echo -e "${GREEN}Running Flyway migrations...${NC}"
        docker-compose --profile migrate up flyway
        ;;
    info)
        echo -e "${GREEN}Checking migration status...${NC}"
        docker-compose run --rm flyway -url=${PG_URL} -user=${PG_USER} -password=${PG_PASSWORD} info
        ;;
    validate)
        echo -e "${GREEN}Validating migrations...${NC}"
        docker-compose run --rm flyway -url=${PG_URL} -user=${PG_USER} -password=${PG_PASSWORD} validate
        ;;
    clean)
        echo -e "${YELLOW}WARNING: This will delete all data!${NC}"
        read -p "Are you sure? (yes/no): " confirm
        if [ "$confirm" = "yes" ]; then
            docker-compose run --rm flyway -url=${PG_URL} -user=${PG_USER} -password=${PG_PASSWORD} clean
        fi
        ;;
    repair)
        echo -e "${GREEN}Repairing migration history...${NC}"
        docker-compose run --rm flyway -url=${PG_URL} -user=${PG_USER} -password=${PG_PASSWORD} repair
        ;;
    down)
        echo -e "${GREEN}Stopping all containers...${NC}"
        docker-compose down
        ;;
    reset)
        echo -e "${YELLOW}Resetting database...${NC}"
        docker-compose down -v
        docker-compose up -d postgres
        echo "Waiting for PostgreSQL..."
        sleep 5
        docker-compose --profile migrate up flyway
        ;;
    psql)
        echo -e "${GREEN}Connecting to PostgreSQL...${NC}"
        docker exec -it payment-postgres psql -U payment -d payment_db
        ;;
    *)
        echo "Usage: $0 {up|migrate|info|validate|clean|repair|down|reset|psql}"
        echo ""
        echo "Commands:"
        echo "  up       - Start PostgreSQL container"
        echo "  migrate  - Run Flyway migrations"
        echo "  info     - Show migration status"
        echo "  validate - Validate applied migrations"
        echo "  clean    - Clean database (WARNING: deletes all data)"
        echo "  repair   - Repair migration history"
        echo "  down     - Stop all containers"
        echo "  reset    - Reset database and run migrations"
        echo "  psql     - Connect to PostgreSQL shell"
        exit 1
        ;;
esac

echo -e "${GREEN}Done!${NC}"
