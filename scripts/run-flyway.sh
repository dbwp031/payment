#!/bin/bash
# ============================================
# Flyway Migration 실행 스크립트
# Description: Flyway 마이그레이션 실행 및 관리
# Database: PostgreSQL 14
# ============================================

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 기본값 설정
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-payment_db}"
DB_USER="${DB_USER:-payment}"
DB_PASSWORD="${DB_PASSWORD:-}"
FLYWAY_LOCATIONS="${FLYWAY_LOCATIONS:-filesystem:src/main/resources/db/migration}"

# 사용법 출력
usage() {
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  migrate     - 마이그레이션 실행"
    echo "  info        - 현재 마이그레이션 상태 확인"
    echo "  validate    - 마이그레이션 유효성 검사"
    echo "  clean       - 데이터베이스 초기화 (주의: 모든 데이터 삭제)"
    echo "  repair      - 마이그레이션 히스토리 복구"
    echo "  baseline    - 기존 DB에 베이스라인 설정"
    echo ""
    echo "Options:"
    echo "  --host      - 데이터베이스 호스트 (기본값: localhost)"
    echo "  --port      - 데이터베이스 포트 (기본값: 5432)"
    echo "  --db        - 데이터베이스 이름 (기본값: payment_db)"
    echo "  --user      - 데이터베이스 사용자 (기본값: payment)"
    echo "  --password  - 데이터베이스 비밀번호"
    echo ""
    echo "Environment Variables:"
    echo "  DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD"
    echo ""
    echo "Examples:"
    echo "  $0 migrate"
    echo "  $0 info --host=localhost --db=payment_db --user=payment --password=secret"
    echo "  DB_PASSWORD=secret $0 migrate"
}

# 인자 파싱
COMMAND=""
while [[ $# -gt 0 ]]; do
    case $1 in
        migrate|info|validate|clean|repair|baseline)
            COMMAND=$1
            shift
            ;;
        --host=*)
            DB_HOST="${1#*=}"
            shift
            ;;
        --port=*)
            DB_PORT="${1#*=}"
            shift
            ;;
        --db=*)
            DB_NAME="${1#*=}"
            shift
            ;;
        --user=*)
            DB_USER="${1#*=}"
            shift
            ;;
        --password=*)
            DB_PASSWORD="${1#*=}"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# 명령어 필수
if [ -z "$COMMAND" ]; then
    echo -e "${RED}Error: Command is required${NC}"
    usage
    exit 1
fi

# JDBC URL 생성 (PostgreSQL)
JDBC_URL="jdbc:postgresql://${DB_HOST}:${DB_PORT}/${DB_NAME}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Flyway Migration - ${COMMAND}${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Host: ${DB_HOST}:${DB_PORT}"
echo "Database: ${DB_NAME}"
echo "User: ${DB_USER}"
echo ""

# Flyway 실행 방법 확인
run_flyway() {
    local cmd=$1

    # Gradle Wrapper 확인
    if [ -f "./gradlew" ]; then
        echo -e "${YELLOW}Running with Gradle...${NC}"
        ./gradlew flyway${cmd^} \
            -Pflyway.url="${JDBC_URL}" \
            -Pflyway.user="${DB_USER}" \
            -Pflyway.password="${DB_PASSWORD}" \
            -Pflyway.locations="${FLYWAY_LOCATIONS}"
    # Maven Wrapper 확인
    elif [ -f "./mvnw" ]; then
        echo -e "${YELLOW}Running with Maven...${NC}"
        ./mvnw flyway:${cmd} \
            -Dflyway.url="${JDBC_URL}" \
            -Dflyway.user="${DB_USER}" \
            -Dflyway.password="${DB_PASSWORD}" \
            -Dflyway.locations="${FLYWAY_LOCATIONS}"
    # Flyway CLI 확인
    elif command -v flyway &> /dev/null; then
        echo -e "${YELLOW}Running with Flyway CLI...${NC}"
        flyway -url="${JDBC_URL}" \
            -user="${DB_USER}" \
            -password="${DB_PASSWORD}" \
            -locations="${FLYWAY_LOCATIONS}" \
            ${cmd}
    # Docker Flyway
    elif command -v docker &> /dev/null; then
        echo -e "${YELLOW}Running with Docker...${NC}"
        docker run --rm \
            -v "$(pwd)/src/main/resources/db/migration:/flyway/sql" \
            --network host \
            flyway/flyway:latest \
            -url="${JDBC_URL}" \
            -user="${DB_USER}" \
            -password="${DB_PASSWORD}" \
            ${cmd}
    else
        echo -e "${RED}Error: No Flyway execution method found.${NC}"
        echo "Please install one of the following:"
        echo "  - Gradle with Flyway plugin"
        echo "  - Maven with Flyway plugin"
        echo "  - Flyway CLI"
        echo "  - Docker"
        exit 1
    fi
}

# Clean 명령어 확인
if [ "$COMMAND" = "clean" ]; then
    echo -e "${RED}WARNING: This will delete ALL data in the database!${NC}"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# 명령어 실행
run_flyway "${COMMAND}"

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Flyway ${COMMAND} completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"
