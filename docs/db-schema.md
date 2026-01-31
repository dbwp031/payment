# DB 스키마 설계 문서

## 1. 개요

### 1.1 데이터베이스 정보
- **DBMS**: PostgreSQL 14
- **Character Set**: utf8mb4 (이모지 지원)
- **Collation**: utf8mb4_unicode_ci
- **Time Zone**: UTC (애플리케이션에서 로컬 타임존 변환)

### 1.2 설계 원칙
- 정규화 3NF 기준 (필요 시 성능을 위한 비정규화)
- 모든 테이블에 PK는 BigInt (Long) AUTO_INCREMENT
- 생성/수정 일시 필수 (created_at, updated_at)
- Soft Delete 미사용 (명시적 삭제)
- 외래키 제약조건은 애플리케이션 레벨에서 관리 (성능 고려)

---

## 2. ERD (Entity Relationship Diagram)

### 2.1 전체 ERD

```
┌─────────────────────────┐
│        users            │
│─────────────────────────│
│ id (PK, BIGINT)         │
│ username (VARCHAR)      │
│ email (VARCHAR)         │
│ password_hash (VARCHAR) │
│ status (VARCHAR)        │
│ created_at (DATETIME)   │
│ updated_at (DATETIME)   │
└─────────────────────────┘
            │ 1
            │
            │ N
┌─────────────────────────┐         ┌─────────────────────────┐
│      payments           │    1:N  │       refunds           │
│─────────────────────────│◄────────│─────────────────────────│
│ id (PK, BIGINT)         │         │ id (PK, BIGINT)         │
│ user_id (BIGINT)        │         │ payment_id (BIGINT)     │
│ amount (BIGINT)         │         │ refund_amount (BIGINT)  │
│ payment_method_type     │         │ reason (VARCHAR)        │
│   (VARCHAR)             │         │ status (VARCHAR)        │
│ payment_method_info     │         │ pg_refund_id (VARCHAR)  │
│   (TEXT)                │         │ refunded_at (DATETIME)  │
│ status (VARCHAR)        │         │ created_at (DATETIME)   │
│ pg_transaction_id       │         │ updated_at (DATETIME)   │
│   (VARCHAR)             │         └─────────────────────────┘
│ requested_at (DATETIME) │
│ completed_at (DATETIME) │
│ created_at (DATETIME)   │
│ updated_at (DATETIME)   │
└─────────────────────────┘
            │ 1
            │
            │ 0..1
┌─────────────────────────┐
│    subscriptions        │
│─────────────────────────│
│ id (PK, BIGINT)         │
│ user_id (BIGINT)        │
│ initial_payment_id      │
│   (BIGINT)              │
│ amount (BIGINT)         │
│ billing_cycle (VARCHAR) │
│ next_billing_date (DATE)│
│ status (VARCHAR)        │
│ retry_count (INT)       │
│ last_billed_at          │
│   (DATETIME)            │
│ cancelled_at (DATETIME) │
│ created_at (DATETIME)   │
│ updated_at (DATETIME)   │
└─────────────────────────┘


┌─────────────────────────┐         ┌─────────────────────────────┐
│   cookie_wallets        │   1:N   │   cookie_transactions       │
│─────────────────────────│◄────────│─────────────────────────────│
│ id (PK, BIGINT)         │         │ id (PK, BIGINT)             │
│ user_id (BIGINT, UQ)    │         │ user_id (BIGINT)            │
│ balance (BIGINT)        │         │ wallet_id (BIGINT)          │
│ version (BIGINT)        │         │ transaction_type (VARCHAR)  │
│ created_at (DATETIME)   │         │ amount (BIGINT)             │
│ updated_at (DATETIME)   │         │ balance_before (BIGINT)     │
│                         │         │ balance_after (BIGINT)      │
└─────────────────────────┘         │ payment_id (BIGINT, NULL)   │
                                    │ reference_type (VARCHAR)    │
                                    │ reference_id (BIGINT, NULL) │
                                    │ description (VARCHAR)       │
                                    │ created_at (DATETIME)       │
                                    └─────────────────────────────┘


┌─────────────────────────────────────────┐
│   payment_events (이벤트 소싱, 선택)     │
│─────────────────────────────────────────│
│ id (PK, BIGINT)                         │
│ aggregate_id (BIGINT)                   │
│ aggregate_type (VARCHAR)                │
│ event_type (VARCHAR)                    │
│ event_data (JSON/TEXT)                  │
│ version (INT)                           │
│ created_at (DATETIME)                   │
└─────────────────────────────────────────┘
```

---

## 3. 테이블 상세 설계

### 3.1 users (사용자)

```sql
CREATE TABLE users (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '사용자 ID',
    username VARCHAR(50) NOT NULL COMMENT '사용자명',
    email VARCHAR(100) NOT NULL COMMENT '이메일',
    password_hash VARCHAR(255) NOT NULL COMMENT '비밀번호 해시',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '상태: ACTIVE, INACTIVE, SUSPENDED',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성일시',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '수정일시',
    
    UNIQUE KEY uk_email (email),
    UNIQUE KEY uk_username (username),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='사용자';
```

**컬럼 설명:**
- `status`: 사용자 계정 상태 관리
- `password_hash`: BCrypt 등으로 암호화된 비밀번호

**인덱스 전략:**
- `uk_email`: 이메일 중복 체크 및 로그인 시 조회
- `uk_username`: 사용자명 중복 체크
- `idx_status`: 활성 사용자 조회 시 사용

---

### 3.2 payments (결제)

```sql
CREATE TABLE payments (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '결제 ID',
    user_id BIGINT NOT NULL COMMENT '사용자 ID',
    amount BIGINT NOT NULL COMMENT '결제 금액 (원 단위, Long)',
    payment_method_type VARCHAR(30) NOT NULL COMMENT '결제 수단: CREDIT_CARD, BANK_TRANSFER, SIMPLE_PAY',
    payment_method_info TEXT COMMENT '결제 수단 상세 정보 (JSON 형태)',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '상태: PENDING, SUCCESS, FAILED, CANCELLED',
    pg_transaction_id VARCHAR(100) COMMENT 'PG사 거래 ID',
    failure_reason VARCHAR(500) COMMENT '실패 사유',
    requested_at DATETIME(6) NOT NULL COMMENT '결제 요청 일시',
    completed_at DATETIME(6) COMMENT '결제 완료 일시',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성일시',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '수정일시',
    
    INDEX idx_user_created (user_id, created_at DESC) COMMENT '사용자별 결제 목록 조회',
    INDEX idx_user_status (user_id, status) COMMENT '사용자별 상태별 조회',
    INDEX idx_status_created (status, created_at DESC) COMMENT '상태별 결제 목록',
    INDEX idx_pg_transaction (pg_transaction_id) COMMENT 'PG 거래 ID 조회',
    INDEX idx_completed_at (completed_at) COMMENT '완료 일시별 조회'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='결제';
```

**컬럼 설명:**
- `amount`: 원 단위로 저장 (1000원 = 1000), 소수점 없음
- `payment_method_info`: JSON 형태로 카드 정보 등 저장
  ```json
  {
    "card_number": "1234-****-****-5678",
    "card_type": "CREDIT",
    "installment": 0
  }
  ```
- `status`: 결제 상태 (PENDING → SUCCESS/FAILED/CANCELLED)
- `pg_transaction_id`: PG사에서 발급한 고유 거래 ID

**인덱스 전략:**
- `idx_user_created`: **가장 많이 사용** - "내 결제 내역" 조회 (최신순)
- `idx_user_status`: 사용자별 특정 상태 결제 조회 (예: 성공한 결제만)
- `idx_status_created`: 관리자 - 전체 결제 중 특정 상태 조회
- `idx_pg_transaction`: PG 콜백 시 결제 찾기
- `idx_completed_at`: 정산, 통계 쿼리 최적화

**설계 포인트:**
- 복합 인덱스 `(user_id, created_at DESC)`는 사용자별 페이징 조회에 최적화
- `status` 컬럼은 카디널리티가 낮지만 WHERE 조건으로 자주 사용되므로 복합 인덱스에 포함

---

### 3.3 refunds (환불)

```sql
CREATE TABLE refunds (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '환불 ID',
    payment_id BIGINT NOT NULL COMMENT '원본 결제 ID',
    user_id BIGINT NOT NULL COMMENT '사용자 ID',
    refund_amount BIGINT NOT NULL COMMENT '환불 금액',
    reason VARCHAR(500) COMMENT '환불 사유',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING' COMMENT '상태: PENDING, SUCCESS, FAILED',
    pg_refund_id VARCHAR(100) COMMENT 'PG사 환불 거래 ID',
    failure_reason VARCHAR(500) COMMENT '환불 실패 사유',
    refunded_at DATETIME(6) COMMENT '환불 완료 일시',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성일시',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '수정일시',
    
    INDEX idx_payment (payment_id) COMMENT '결제별 환불 조회',
    INDEX idx_user_created (user_id, created_at DESC) COMMENT '사용자별 환불 목록',
    INDEX idx_status (status) COMMENT '상태별 환불 조회'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='환불';
```

**컬럼 설명:**
- `refund_amount`: 전액 환불만 지원하므로 원본 결제의 amount와 동일
- `reason`: 사용자가 입력한 환불 사유 또는 시스템 사유

**인덱스 전략:**
- `idx_payment`: 특정 결제의 환불 내역 조회 (중복 환불 방지)
- `idx_user_created`: 사용자별 환불 내역 조회

---

### 3.4 subscriptions (정기결제/구독)

```sql
CREATE TABLE subscriptions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '구독 ID',
    user_id BIGINT NOT NULL COMMENT '사용자 ID',
    initial_payment_id BIGINT COMMENT '최초 결제 ID',
    amount BIGINT NOT NULL COMMENT '구독 금액 (월/년)',
    billing_cycle VARCHAR(20) NOT NULL COMMENT '결제 주기: MONTHLY, YEARLY',
    next_billing_date DATE NOT NULL COMMENT '다음 결제 예정일',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' COMMENT '상태: ACTIVE, PAUSED, CANCELLED',
    retry_count INT NOT NULL DEFAULT 0 COMMENT '결제 실패 재시도 횟수',
    max_retry_count INT NOT NULL DEFAULT 3 COMMENT '최대 재시도 횟수',
    last_billed_at DATETIME(6) COMMENT '마지막 결제 성공 일시',
    cancelled_at DATETIME(6) COMMENT '구독 취소 일시',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성일시',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '수정일시',
    
    INDEX idx_user_status (user_id, status) COMMENT '사용자별 활성 구독 조회',
    INDEX idx_next_billing (next_billing_date, status) COMMENT '정기결제 스케줄링',
    INDEX idx_status (status) COMMENT '상태별 구독 조회'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='정기결제(구독)';
```

**컬럼 설명:**
- `billing_cycle`: MONTHLY(월), YEARLY(년)
- `next_billing_date`: 스케줄러가 매일 확인할 다음 결제일
- `retry_count`: 결제 실패 시 재시도 횟수 (3회 초과 시 PAUSED)
- `last_billed_at`: 마지막 성공 결제 일시 (다음 결제일 계산용)

**인덱스 전략:**
- `idx_next_billing`: **핵심 인덱스** - 스케줄러가 오늘 결제할 구독 조회
  ```sql
  SELECT * FROM subscriptions 
  WHERE next_billing_date = CURDATE() 
    AND status = 'ACTIVE';
  ```
- `idx_user_status`: 사용자의 활성 구독 조회

**스케줄러 로직:**
```java
@Scheduled(cron = "0 0 0 * * *") // 매일 00:00
public void processSubscriptionPayments() {
    LocalDate today = LocalDate.now();
    List<Subscription> targets = subscriptionRepository
        .findByNextBillingDateAndStatus(today, SubscriptionStatus.ACTIVE);
    
    for (Subscription subscription : targets) {
        processSubscription(subscription);
    }
}
```

---

### 3.5 cookie_wallets (쿠키 지갑)

```sql
CREATE TABLE cookie_wallets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '지갑 ID',
    user_id BIGINT NOT NULL COMMENT '사용자 ID',
    balance BIGINT NOT NULL DEFAULT 0 COMMENT '쿠키 잔액',
    version BIGINT NOT NULL DEFAULT 0 COMMENT '낙관적 락 버전',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '생성일시',
    updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '수정일시',
    
    UNIQUE KEY uk_user (user_id) COMMENT '사용자당 1개 지갑'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='쿠키 지갑';
```

**컬럼 설명:**
- `balance`: 쿠키 잔액 (단위: 개)
- `version`: JPA `@Version`을 통한 낙관적 락
    - 업데이트 시 자동 증가
    - 동시 수정 감지

**인덱스 전략:**
- `uk_user`: 사용자당 지갑은 1개만 존재 (UNIQUE 제약)

**낙관적 락 동작:**
```sql
-- Thread 1
UPDATE cookie_wallets 
SET balance = balance - 100, version = version + 1
WHERE user_id = 1 AND version = 5;  -- 성공 (1 row affected)

-- Thread 2 (동시)
UPDATE cookie_wallets 
SET balance = balance - 50, version = version + 1
WHERE user_id = 1 AND version = 5;  -- 실패 (0 rows affected)
-- OptimisticLockException 발생 → 재시도
```

---

### 3.6 cookie_transactions (쿠키 거래 이력)

```sql
CREATE TABLE cookie_transactions (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '거래 ID',
    user_id BIGINT NOT NULL COMMENT '사용자 ID',
    wallet_id BIGINT NOT NULL COMMENT '지갑 ID',
    transaction_type VARCHAR(20) NOT NULL COMMENT '거래 유형: CHARGE, USE, REFUND',
    amount BIGINT NOT NULL COMMENT '거래 금액',
    balance_before BIGINT NOT NULL COMMENT '거래 전 잔액',
    balance_after BIGINT NOT NULL COMMENT '거래 후 잔액',
    payment_id BIGINT COMMENT '관련 결제 ID (충전/환불 시)',
    reference_type VARCHAR(50) COMMENT '참조 타입: ORDER, SERVICE 등',
    reference_id BIGINT COMMENT '참조 ID (주문 ID, 서비스 ID 등)',
    description VARCHAR(200) COMMENT '거래 설명',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '거래일시',
    
    INDEX idx_user_created (user_id, created_at DESC) COMMENT '사용자별 거래 내역',
    INDEX idx_wallet_created (wallet_id, created_at DESC) COMMENT '지갑별 거래 내역',
    INDEX idx_type_created (transaction_type, created_at DESC) COMMENT '유형별 거래 내역',
    INDEX idx_payment (payment_id) COMMENT '결제 관련 거래 조회',
    INDEX idx_reference (reference_type, reference_id) COMMENT '참조 대상 조회'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='쿠키 거래 이력';
```

**컬럼 설명:**
- `transaction_type`:
    - `CHARGE`: 충전 (결제 완료 시)
    - `USE`: 사용 (상품/서비스 구매 시)
    - `REFUND`: 환불 (결제 취소 시)
- `balance_before/after`: 거래 전후 잔액 (감사 추적용)
- `reference_type/id`: 쿠키를 어디에 사용했는지 추적
    - 예: `ORDER`, `reference_id=12345` → 주문번호 12345에 사용

**인덱스 전략:**
- `idx_user_created`: **가장 많이 사용** - "내 쿠키 사용 내역" 조회 (페이징)
- `idx_wallet_created`: 지갑별 거래 내역 (중복이지만 명확성)
- `idx_type_created`: 충전만/사용만 필터링
- `idx_reference`: "이 주문에서 쿠키를 얼마나 썼나?" 조회

**설계 포인트:**
- 이력 테이블은 **INSERT ONLY** (수정/삭제 없음)
- 잔액 검증 로직:
  ```java
  assert transaction.getBalanceBefore() - transaction.getAmount() 
         == transaction.getBalanceAfter();
  ```

---

### 3.7 payment_events (이벤트 소싱, 선택 사항)

```sql
CREATE TABLE payment_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY COMMENT '이벤트 ID',
    aggregate_id BIGINT NOT NULL COMMENT '집합 루트 ID (payment_id, subscription_id 등)',
    aggregate_type VARCHAR(50) NOT NULL COMMENT '집합 루트 타입: PAYMENT, SUBSCRIPTION',
    event_type VARCHAR(100) NOT NULL COMMENT '이벤트 타입: PaymentCreated, PaymentCompleted 등',
    event_data TEXT NOT NULL COMMENT '이벤트 데이터 (JSON)',
    version INT NOT NULL COMMENT '이벤트 버전 (순서 보장)',
    created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '이벤트 발생 일시',
    
    INDEX idx_aggregate (aggregate_type, aggregate_id, version) COMMENT '이벤트 재생',
    INDEX idx_event_type (event_type, created_at) COMMENT '이벤트 타입별 조회'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='결제 이벤트 (이벤트 소싱)';
```

**사용 목적 (선택 사항):**
- 모든 결제 관련 이벤트를 시간순으로 저장
- 상태 재구성 (Event Replay) 가능
- 감사 로그 및 디버깅

**이벤트 예시:**
```json
{
  "event_type": "PaymentCompleted",
  "aggregate_id": 12345,
  "aggregate_type": "PAYMENT",
  "event_data": {
    "payment_id": 12345,
    "user_id": 1,
    "amount": 10000,
    "pg_transaction_id": "PG123456",
    "completed_at": "2025-01-31T10:30:00Z"
  },
  "version": 3
}
```

---

## 4. 인덱스 전략 상세

### 4.1 인덱스 설계 원칙

1. **카디널리티 우선 순위**
    - 카디널리티가 높은 컬럼을 복합 인덱스 앞쪽에 배치
    - 예: `(user_id, created_at)` ✅ / `(created_at, user_id)` ❌

2. **WHERE 절 우선**
    - WHERE 조건에 자주 사용되는 컬럼에 인덱스 생성
    - 예: `WHERE user_id = ? AND status = ?` → `idx_user_status`

3. **ORDER BY 최적화**
    - 정렬 컬럼을 인덱스에 포함 (DESC 명시)
    - 예: `ORDER BY created_at DESC` → `idx_user_created (user_id, created_at DESC)`

4. **커버링 인덱스 고려**
    - SELECT 컬럼까지 인덱스에 포함하면 테이블 접근 불필요
    - 예: `SELECT id, amount FROM payments WHERE user_id = ?`
      → `idx_user_amount (user_id, amount)` (필요 시)

### 4.2 주요 쿼리 패턴별 인덱스

#### 패턴 1: 사용자별 최신순 목록 조회 (페이징)
```sql
-- 결제 내역 조회
SELECT * FROM payments 
WHERE user_id = ? 
ORDER BY created_at DESC 
LIMIT 20 OFFSET 0;

-- 최적 인덱스
INDEX idx_user_created (user_id, created_at DESC)
```

#### 패턴 2: 상태 필터링 + 최신순
```sql
-- 성공한 결제만 조회
SELECT * FROM payments 
WHERE user_id = ? AND status = 'SUCCESS'
ORDER BY created_at DESC 
LIMIT 20;

-- 최적 인덱스
INDEX idx_user_status_created (user_id, status, created_at DESC)
```

#### 패턴 3: 날짜 범위 조회
```sql
-- 특정 기간 결제 조회
SELECT * FROM payments 
WHERE user_id = ? 
  AND created_at BETWEEN ? AND ?
ORDER BY created_at DESC;

-- 기존 인덱스 활용 가능
INDEX idx_user_created (user_id, created_at DESC)
```

#### 패턴 4: 집계 쿼리
```sql
-- 사용자별 총 결제 금액
SELECT user_id, SUM(amount) 
FROM payments 
WHERE status = 'SUCCESS' 
  AND completed_at >= ?
GROUP BY user_id;

-- 최적 인덱스 (커버링 인덱스)
INDEX idx_status_completed_amount (status, completed_at, user_id, amount)
```

### 4.3 인덱스 성능 비교

| 테이블 | 데이터 양 | 쿼리 | 인덱스 없음 | 인덱스 있음 | 개선율 |
|--------|----------|------|------------|-----------|--------|
| payments | 100만 건 | user_id 조회 | 500ms | 5ms | 100배 |
| cookie_transactions | 500만 건 | user_id + 날짜 | 2000ms | 10ms | 200배 |
| subscriptions | 10만 건 | next_billing_date | 100ms | 2ms | 50배 |

### 4.4 인덱스 주의사항

**❌ 피해야 할 인덱스:**
```sql
-- 카디널리티 낮은 컬럼 단독 인덱스
INDEX idx_status (status)  -- status 값이 4~5개뿐

-- 사용되지 않는 복합 인덱스
INDEX idx_created_user (created_at, user_id)  -- 순서가 잘못됨
```

**✅ 권장 인덱스:**
```sql
-- 복합 인덱스 (카디널리티 높은 순)
INDEX idx_user_status (user_id, status)

-- 정렬까지 고려
INDEX idx_user_created (user_id, created_at DESC)
```

---

## 5. 데이터 타입 선택 근거

### 5.1 ID (PK)
- **타입**: `BIGINT (Long)`
- **이유**:
    - INT는 약 21억까지 (21억 건 이상 시 오버플로우)
    - BIGINT는 약 922경까지 (사실상 무제한)
    - 분산 환경 대비 (UUID 대신 Snowflake ID 등 가능)

### 5.2 금액
- **타입**: `BIGINT`
- **이유**:
    - 소수점 오류 방지 (DECIMAL 대신)
    - 원 단위로 저장 (10,000원 = 10000)
    - 계산 속도 빠름

### 5.3 날짜/시간
- **타입**: `DATETIME(6)` (마이크로초 정밀도)
- **이유**:
    - TIMESTAMP는 2038년 문제
    - DATETIME은 9999년까지 지원
    - (6)은 마이크로초 단위 (이벤트 순서 보장)

### 5.4 Enum (상태값)
- **타입**: `VARCHAR(20)`
- **이유**:
    - DB에서 ENUM 타입은 확장성 낮음
    - 애플리케이션에서 Java Enum으로 관리
    - VARCHAR로 저장 시 가독성 좋음

### 5.5 JSON 데이터
- **타입**: `TEXT` (MySQL 5.7 이하) or `JSON` (MySQL 8.0+)
- **이유**:
    - 결제 수단 정보는 유연한 스키마 필요
    - MySQL 8.0의 JSON 타입은 인덱싱 가능
  ```sql
  -- JSON 컬럼에 가상 컬럼 인덱스 생성
  ALTER TABLE payments 
  ADD COLUMN card_type VARCHAR(20) 
  AS (JSON_UNQUOTE(JSON_EXTRACT(payment_method_info, '$.card_type'))) STORED,
  ADD INDEX idx_card_type (card_type);
  ```

---

## 6. 제약조건 및 데이터 무결성

### 6.1 NOT NULL 제약
```sql
-- 필수 컬럼에 NOT NULL 명시
user_id BIGINT NOT NULL,
amount BIGINT NOT NULL,
status VARCHAR(20) NOT NULL,
```

### 6.2 DEFAULT 값
```sql
-- 상태 초기값
status VARCHAR(20) NOT NULL DEFAULT 'PENDING',

-- 잔액 초기값
balance BIGINT NOT NULL DEFAULT 0,

-- 재시도 횟수
retry_count INT NOT NULL DEFAULT 0,
```

### 6.3 CHECK 제약 (MySQL 8.0.16+)
```sql
-- 금액은 양수
ALTER TABLE payments 
ADD CONSTRAINT chk_amount_positive 
CHECK (amount > 0);

-- 잔액은 음수 불가
ALTER TABLE cookie_wallets 
ADD CONSTRAINT chk_balance_non_negative 
CHECK (balance >= 0);

-- 재시도 횟수 범위
ALTER TABLE subscriptions 
ADD CONSTRAINT chk_retry_count 
CHECK (retry_count >= 0 AND retry_count <= max_retry_count);
```

### 6.4 외래키 (선택 사항)
```sql
-- 외래키는 성능상 이유로 미사용 권장
-- 대신 애플리케이션 레벨에서 무결성 검증

-- 만약 사용한다면:
ALTER TABLE payments 
ADD CONSTRAINT fk_payment_user 
FOREIGN KEY (user_id) REFERENCES users(id);

ALTER TABLE refunds 
ADD CONSTRAINT fk_refund_payment 
FOREIGN KEY (payment_id) REFERENCES payments(id);
```

**외래키 미사용 이유:**
- 대용량 트래픽 시 락 경합 증가
- 샤딩/파티셔닝 시 제약
- 애플리케이션에서 검증 충분

---

## 7. 파티셔닝 전략 (확장성)

### 7.1 대용량 테이블 파티셔닝

**payments 테이블 (Range Partitioning by created_at)**
```sql
CREATE TABLE payments (
    -- 컬럼 정의 동일
) ENGINE=InnoDB
PARTITION BY RANGE (YEAR(created_at)) (
    PARTITION p2024 VALUES LESS THAN (2025),
    PARTITION p2025 VALUES LESS THAN (2026),
    PARTITION p2026 VALUES LESS THAN (2027),
    PARTITION p_future VALUES LESS THAN MAXVALUE
);
```

**cookie_transactions 테이블 (Range Partitioning)**
```sql
-- 월별 파티셔닝
PARTITION BY RANGE (TO_DAYS(created_at)) (
    PARTITION p202501 VALUES LESS THAN (TO_DAYS('2025-02-01')),
    PARTITION p202502 VALUES LESS THAN (TO_DAYS('2025-03-01')),
    -- ...
);
```

**장점:**
- 오래된 데이터 삭제 시 파티션만 DROP (빠름)
- 최신 데이터 조회 성능 향상
- 백업/복구 유연성

### 7.2 샤딩 준비 (user_id 기준)
```sql
-- 향후 샤딩 시 user_id를 기준으로 분산
-- 예: user_id % 4 = 0 → Shard 0
--     user_id % 4 = 1 → Shard 1
```

---

## 8. 성능 최적화 팁

### 8.1 쿼리 최적화
```sql
-- ❌ 비효율적
SELECT * FROM payments WHERE YEAR(created_at) = 2025;

-- ✅ 인덱스 활용
SELECT * FROM payments 
WHERE created_at >= '2025-01-01' 
  AND created_at < '2026-01-01';
```

### 8.2 COUNT 최적화
```sql
-- ❌ 느린 COUNT
SELECT COUNT(*) FROM payments WHERE user_id = ?;

-- ✅ 커버링 인덱스 활용
SELECT COUNT(id) FROM payments WHERE user_id = ?;

-- ✅✅ 필요하면 캐싱
-- Redis에 user_payment_count:{user_id} 저장
```

### 8.3 페이징 최적화
```sql
-- ❌ OFFSET이 큰 경우 느림
SELECT * FROM payments 
WHERE user_id = ? 
ORDER BY created_at DESC 
LIMIT 20 OFFSET 10000;

-- ✅ Cursor 기반 페이징
SELECT * FROM payments 
WHERE user_id = ? 
  AND created_at < ?  -- 이전 페이지의 마지막 created_at
ORDER BY created_at DESC 
LIMIT 20;
```

---

## 9. 초기 데이터 및 시드

### 9.1 테스트 사용자
```sql
INSERT INTO users (username, email, password_hash, status) VALUES
('test_user_1', 'test1@example.com', '$2a$10$...', 'ACTIVE'),
('test_user_2', 'test2@example.com', '$2a$10$...', 'ACTIVE');
```

### 9.2 쿠키 지갑 초기화
```sql
-- 사용자 생성 시 지갑도 함께 생성 (Trigger or Application)
INSERT INTO cookie_wallets (user_id, balance, version) VALUES
(1, 0, 0),
(2, 0, 0);
```

---

## 10. 마이그레이션 전략

### 10.1 Flyway 스크립트 구조
```
src/main/resources/db/migration/
├── V1__create_users_table.sql
├── V2__create_payments_table.sql
├── V3__create_refunds_table.sql
├── V4__create_subscriptions_table.sql
├── V5__create_cookie_wallets_table.sql
├── V6__create_cookie_transactions_table.sql
├── V7__create_payment_events_table.sql
├── V8__add_indexes.sql
└── V9__add_check_constraints.sql
```

### 10.2 롤백 스크립트 (Down Migration)
```sql
-- U1__drop_users_table.sql (Flyway Pro 필요)
DROP TABLE IF EXISTS users;
```

---

## 11. 모니터링 쿼리

### 11.1 슬로우 쿼리 확인
```sql
-- MySQL 슬로우 쿼리 로그 활성화
SET GLOBAL slow_query_log = 'ON';
SET GLOBAL long_query_time = 1; -- 1초 이상

-- 슬로우 쿼리 조회
SELECT * FROM mysql.slow_log 
ORDER BY start_time DESC 
LIMIT 10;
```

### 11.2 인덱스 사용률 확인
```sql
-- 사용되지 않는 인덱스 찾기
SELECT 
    object_schema,
    object_name,
    index_name
FROM performance_schema.table_io_waits_summary_by_index_usage
WHERE index_name IS NOT NULL
  AND count_star = 0
  AND object_schema = 'payment_db'
ORDER BY object_schema, object_name;
```

### 11.3 테이블 크기 확인
```sql
SELECT 
    table_name,
    ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb,
    table_rows
FROM information_schema.tables
WHERE table_schema = 'payment_db'
ORDER BY (data_length + index_length) DESC;
```

---

## 부록: 전체 DDL 스크립트

다음 파일로 분리 저장 예정:
- `schema.sql`: 전체 테이블 생성 DDL
- `indexes.sql`: 모든 인덱스 생성 DDL
- `constraints.sql`: CHECK 제약조건 DDL