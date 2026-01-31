# Payment System

결제 + 쿠키 시스템 프로젝트

## 목차

- [기술 스택](#기술-스택)
- [프로젝트 구조](#프로젝트-구조)
- [시작하기](#시작하기)
- [데이터베이스 마이그레이션](#데이터베이스-마이그레이션)
- [개발 환경 설정](#개발-환경-설정)

---

## 기술 스택

- **Database**: PostgreSQL 14
- **Migration**: Flyway
- **Container**: Docker / Docker Compose

---

## 프로젝트 구조

```
payment/
├── src/
│   └── main/
│       └── resources/
│           └── db/
│               └── migration/          # Flyway 마이그레이션 파일
│                   ├── V1__create_users_table.sql
│                   ├── V2__create_payments_table.sql
│                   ├── V3__create_refunds_table.sql
│                   ├── V4__create_subscriptions_table.sql
│                   ├── V5__create_cookie_wallets_table.sql
│                   ├── V6__create_cookie_transactions_table.sql
│                   ├── V7__create_payment_events_table.sql
│                   ├── V8__add_check_constraints.sql
│                   └── V9__insert_seed_data.sql
├── scripts/
│   ├── docker-compose.yml              # Docker Compose 설정
│   ├── docker-migrate.sh               # Docker 기반 마이그레이션 스크립트
│   └── run-flyway.sh                   # Flyway 실행 스크립트
└── docs/
    ├── db-schema.md                    # DB 스키마 설계 문서
    └── flyway.md                       # Flyway 마이그레이션 가이드
```

---

## 시작하기

### 사전 요구사항

- Docker & Docker Compose (권장)
- 또는 PostgreSQL 14+ 로컬 설치
- Java 17+ (Spring Boot 사용 시)

### 빠른 시작 (Docker)

```bash
# 1. 프로젝트 클론
git clone <repository-url>
cd payment

# 2. Docker로 PostgreSQL 시작 및 마이그레이션 실행
cd scripts
./docker-migrate.sh up        # PostgreSQL 컨테이너 시작
./docker-migrate.sh migrate   # Flyway 마이그레이션 실행
```

---

## 데이터베이스 마이그레이션

### 방법 1: Docker Compose (권장)

Docker Compose를 사용하여 PostgreSQL과 Flyway를 함께 실행합니다.

#### 기본 명령어

```bash
cd scripts

# PostgreSQL 컨테이너 시작
./docker-migrate.sh up

# 마이그레이션 실행
./docker-migrate.sh migrate

# 마이그레이션 상태 확인
./docker-migrate.sh info

# 마이그레이션 유효성 검사
./docker-migrate.sh validate

# 마이그레이션 히스토리 복구
./docker-migrate.sh repair

# 데이터베이스 초기화 (주의: 모든 데이터 삭제)
./docker-migrate.sh clean

# 컨테이너 중지
./docker-migrate.sh down

# 전체 리셋 (볼륨 삭제 후 재시작)
./docker-migrate.sh reset

# PostgreSQL 쉘 접속
./docker-migrate.sh psql
```

#### Docker Compose 직접 사용

```bash
cd scripts

# PostgreSQL만 시작
docker-compose up -d postgres

# PostgreSQL + Flyway 마이그레이션 함께 실행
docker-compose --profile migrate up

# 마이그레이션 상태 확인
docker-compose run --rm flyway \
  -url=jdbc:postgresql://postgres:5432/payment_db \
  -user=payment \
  -password=payment123 \
  info

# 컨테이너 종료
docker-compose down

# 볼륨 포함 완전 삭제
docker-compose down -v
```

#### 기본 접속 정보 (Docker)

| 항목 | 값 |
|------|-----|
| Host | localhost |
| Port | 5432 |
| Database | payment_db |
| User | payment |
| Password | payment123 |

---

### 방법 2: Flyway 스크립트 (로컬 DB)

로컬에 설치된 PostgreSQL에 마이그레이션을 실행합니다.

#### 기본 사용법

```bash
# 마이그레이션 실행
./scripts/run-flyway.sh migrate --password=yourpassword

# 마이그레이션 상태 확인
./scripts/run-flyway.sh info --password=yourpassword

# 유효성 검사
./scripts/run-flyway.sh validate --password=yourpassword

# 데이터베이스 초기화 (주의!)
./scripts/run-flyway.sh clean --password=yourpassword

# 마이그레이션 히스토리 복구
./scripts/run-flyway.sh repair --password=yourpassword
```

#### 옵션 지정

```bash
./scripts/run-flyway.sh migrate \
  --host=localhost \
  --port=5432 \
  --db=payment_db \
  --user=payment \
  --password=yourpassword
```

#### 환경 변수 사용

```bash
export DB_HOST=localhost
export DB_PORT=5432
export DB_NAME=payment_db
export DB_USER=payment
export DB_PASSWORD=yourpassword

./scripts/run-flyway.sh migrate
```

---

### 방법 3: Gradle / Maven

#### Gradle

```bash
# build.gradle에 Flyway 플러그인 설정 필요
./gradlew flywayMigrate
./gradlew flywayInfo
./gradlew flywayValidate
```

#### Maven

```bash
# pom.xml에 Flyway 플러그인 설정 필요
./mvnw flyway:migrate
./mvnw flyway:info
./mvnw flyway:validate
```

---

### 방법 4: Flyway CLI 직접 사용

```bash
# Flyway CLI 설치 (macOS)
brew install flyway

# 마이그레이션 실행
flyway -url=jdbc:postgresql://localhost:5432/payment_db \
       -user=payment \
       -password=yourpassword \
       -locations=filesystem:src/main/resources/db/migration \
       migrate
```

---

## 마이그레이션 파일 설명

| 버전 | 파일명 | 설명 |
|------|--------|------|
| V1 | create_users_table | 사용자 테이블 생성 + updated_at 트리거 함수 |
| V2 | create_payments_table | 결제 테이블 생성 |
| V3 | create_refunds_table | 환불 테이블 생성 |
| V4 | create_subscriptions_table | 정기결제(구독) 테이블 생성 |
| V5 | create_cookie_wallets_table | 쿠키 지갑 테이블 생성 |
| V6 | create_cookie_transactions_table | 쿠키 거래 이력 테이블 생성 |
| V7 | create_payment_events_table | 이벤트 소싱 테이블 생성 (JSONB 사용) |
| V8 | add_check_constraints | CHECK 제약조건 추가 |
| V9 | insert_seed_data | 테스트 시드 데이터 (개발용) |

> **주의**: V9 시드 데이터는 개발 환경에서만 사용하세요. 운영 환경에서는 제외해야 합니다.

---

## 개발 환경 설정

### PostgreSQL 직접 접속

```bash
# Docker PostgreSQL 접속
docker exec -it payment-postgres psql -U payment -d payment_db

# 또는 스크립트 사용
./scripts/docker-migrate.sh psql

# 로컬 PostgreSQL 접속
psql -h localhost -U payment -d payment_db
```

### 유용한 SQL 명령어

```sql
-- 테이블 목록 확인
\dt

-- 테이블 구조 확인
\d users
\d payments

-- Flyway 히스토리 확인
SELECT * FROM flyway_schema_history;

-- 데이터 확인
SELECT * FROM users;
SELECT * FROM cookie_wallets;

-- 인덱스 확인
\di

-- 테이블 코멘트 확인
SELECT obj_description('users'::regclass);
```

### psql 유용한 명령어

| 명령어 | 설명 |
|--------|------|
| `\dt` | 테이블 목록 |
| `\d 테이블명` | 테이블 구조 |
| `\di` | 인덱스 목록 |
| `\df` | 함수 목록 |
| `\q` | 종료 |
| `\?` | 도움말 |

---

## 문제 해결

### PostgreSQL 연결 오류

```bash
# Docker 컨테이너 상태 확인
docker ps

# PostgreSQL 로그 확인
docker logs payment-postgres

# 컨테이너 재시작
docker-compose -f scripts/docker-compose.yml restart postgres
```

### 마이그레이션 실패 시

```bash
# 마이그레이션 상태 확인
./scripts/docker-migrate.sh info

# 실패한 마이그레이션 복구
./scripts/docker-migrate.sh repair

# 다시 마이그레이션 실행
./scripts/docker-migrate.sh migrate
```

### 전체 리셋

```bash
# Docker 볼륨 포함 완전 삭제 후 재시작
./scripts/docker-migrate.sh reset
```

### 권한 오류

```bash
# 스크립트 실행 권한 부여
chmod +x scripts/*.sh
```

---

## Spring Boot 연동

### application.yml 설정

```yaml
spring:
  datasource:
    url: jdbc:postgresql://localhost:5432/payment_db
    username: payment
    password: payment123
    driver-class-name: org.postgresql.Driver

  flyway:
    enabled: true
    locations: classpath:db/migration
    baseline-on-migrate: true
    # 운영 환경에서 V9 제외
    # locations: classpath:db/migration/V[1-8]*.sql

  jpa:
    hibernate:
      ddl-auto: validate
    properties:
      hibernate:
        dialect: org.hibernate.dialect.PostgreSQLDialect
```

### build.gradle 의존성

```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.flywaydb:flyway-core'
    runtimeOnly 'org.postgresql:postgresql'
}
```

---

## 라이선스

MIT License
