# Flyway Migration 파일 생성 프롬프트

## 목적
결제 + 쿠키 시스템의 DB 스키마를 Flyway migration 파일로 변환하여 버전 관리 가능한 형태로 생성

## 요구사항

### 1. 프로젝트 구조
```
src/main/resources/db/migration/
├── V1__create_users_table.sql
├── V2__create_payments_table.sql
├── V3__create_refunds_table.sql
├── V4__create_subscriptions_table.sql
├── V5__create_cookie_wallets_table.sql
├── V6__create_cookie_transactions_table.sql
├── V7__create_payment_events_table.sql
├── V8__add_check_constraints.sql
└── V9__insert_seed_data.sql (선택 - 개발환경만)
```

### 2. 입력 파일
다음 3개의 SQL 파일을 Flyway migration 형식으로 분리:
1. `schema.sql` - 테이블 생성 DDL
2. `constraints.sql` - CHECK 제약조건
3. `seed-data.sql` - 테스트 데이터 (선택)

### 3. Flyway 네이밍 규칙
- 형식: `V{버전}__{설명}.sql`
- 버전: 숫자 (1, 2, 3, ...)
- 설명: 스네이크 케이스 (create_users_table)
- 언더스코어 2개 필수 (`__`)

### 4. 각 파일 요구사항

#### V1__create_users_table.sql
- users 테이블 생성
- 인덱스 포함
- 주석 포함

#### V2__create_payments_table.sql
- payments 테이블 생성
- 모든 인덱스 포함

#### V3__create_refunds_table.sql
- refunds 테이블 생성
- 인덱스 포함

#### V4__create_subscriptions_table.sql
- subscriptions 테이블 생성
- 인덱스 포함

#### V5__create_cookie_wallets_table.sql
- cookie_wallets 테이블 생성
- UNIQUE 제약 포함

#### V6__create_cookie_transactions_table.sql
- cookie_transactions 테이블 생성
- 인덱스 포함

#### V7__create_payment_events_table.sql (선택)
- payment_events 테이블 생성
- 이벤트 소싱용 (선택 사항)

#### V8__add_check_constraints.sql
- 모든 CHECK 제약조건 추가
- MySQL 8.0.16+ 필요

#### V9__insert_seed_data.sql (선택)
- 테스트 데이터 삽입
- 개발 환경에서만 사용
- 프로파일별 실행 제어 가능

### 5. 파일별 템플릿

```sql
-- ============================================
-- Flyway Migration: V{버전}__{설명}
-- Description: {상세 설명}
-- Author: {작성자}
-- Date: {작성일}
-- ============================================

-- 테이블 생성 또는 변경 사항

-- 필요 시 롤백 가이드 주석
-- Rollback: DROP TABLE {table_name};
```

### 6. 주의사항
- 각 migration 파일은 독립적으로 실행 가능해야 함
- 순서대로 실행될 수 있도록 의존성 고려
- 이미 존재하는 테이블은 생성하지 않음 (멱등성)
- CHECK 제약조건은 별도 파일로 분리 (V8)

### 7. 개발 vs 운영 환경 분리

```sql
-- V9 파일 상단에 주석
-- ============================================
-- 주의: 이 파일은 개발 환경에서만 실행하세요!
-- 운영 환경에서는 실행하지 마세요.
-- ============================================
-- application.yml에서 제어:
-- spring:
--   flyway:
--     locations: classpath:db/migration
--     # 운영: V9 제외 설정
-- ============================================
```

### 8. 추가 요청사항
- 각 파일 상단에 명확한 주석 포함
- 롤백 가이드 주석 추가
- MySQL 8.0 기준으로 작성
- PostgreSQL 호환성 고려 (필요시)

## 실행 방법

### 옵션 1: 전체 파일 일괄 생성
```bash
# 프로젝트 루트에서 실행
# src/main/resources/db/migration/ 디렉토리에 V1~V9 파일 생성
```

### 옵션 2: 단계별 생성
```bash
# V1~V7: 테이블 생성 파일
# V8: 제약조건 파일
# V9: 시드 데이터 파일 (선택)
```

## 기대 결과

1. **Flyway migration 파일 9개** 생성
2. 각 파일은 **독립 실행 가능**
3. **순서대로 실행** 시 완전한 DB 구축
4. **버전 관리** 가능 (Git)
5. **롤백 가이드** 주석 포함

## 검증 방법

```bash
# Flyway 마이그레이션 실행
./gradlew flywayMigrate

# 또는 Maven
mvn flyway:migrate

# 현재 버전 확인
./gradlew flywayInfo
```

## 참고사항

- **schema.sql**: 원본 테이블 생성 스크립트
- **constraints.sql**: CHECK 제약조건 스크립트
- **seed-data.sql**: 테스트 데이터 스크립트

이 3개 파일을 분석하여 Flyway migration 형식으로 분리 작성해주세요.