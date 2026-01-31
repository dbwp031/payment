#!/bin/bash
# ============================================
# Local PostgreSQL Migration Script (without Docker/Flyway)
# ============================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MIGRATION_DIR="$PROJECT_DIR/src/main/resources/db/migration"

DB_NAME="${DB_NAME:-payment_db}"
DB_USER="${DB_USER:-$(whoami)}"
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Local PostgreSQL Migration${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo ""

# Run all migration files in order
for sql_file in $(ls "$MIGRATION_DIR"/*.sql | sort); do
    filename=$(basename "$sql_file")
    echo -e "${YELLOW}Running: $filename${NC}"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$sql_file"
    echo ""
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Migration completed!${NC}"
echo -e "${GREEN}========================================${NC}"
