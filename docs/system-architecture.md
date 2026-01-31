# 결제 + 쿠키 시스템 아키텍처 설계 문서

## 1. 시스템 개요

### 1.1 프로젝트 목적
- 일반 결제 및 정기결제(구독)를 지원하는 결제 시스템
- 결제를 통해 충전 가능한 쿠키(커스텀 화폐) 시스템
- 3년차 백엔드 개발자 포트폴리오 수준의 동시성 제어 및 트랜잭션 처리 구현

### 1.2 핵심 기능
1. **결제 기능**
    - 일반 결제 (신용카드/계좌이체/간편결제 - 확장 가능 설계)
    - 정기결제 (구독)
    - 결제 취소 및 환불

2. **쿠키 기능**
    - 결제를 통한 쿠키 충전
    - 쿠키 사용 (상품/서비스 구매)
    - 쿠키 거래 이력 조회

3. **핵심 기술 요소**
    - Redis 분산 락을 통한 결제 중복 방지
    - 낙관적 락을 통한 쿠키 동시 사용 제어
    - 보상 트랜잭션을 통한 데이터 정합성 보장

---

## 2. 전체 시스템 아키텍처

### 2.1 멀티 모듈 구조

```
payment-cookie-system/
├── payment-api/              # API 레이어 (Controller, DTO)
│   ├── controller/
│   ├── dto/
│   ├── exception/
│   └── config/
│
├── payment-core/             # 비즈니스 로직 레이어
│   ├── domain/              # 도메인 엔티티
│   ├── service/             # 비즈니스 서비스
│   ├── event/               # 도메인 이벤트
│   └── port/                # 인터페이스 (외부 연동)
│
├── payment-infrastructure/   # 인프라 레이어
│   ├── persistence/         # JPA Repository
│   ├── redis/               # Redis 설정 및 락
│   ├── external/            # 외부 PG 연동
│   └── config/
│
└── payment-common/           # 공통 모듈
    ├── exception/
    ├── util/
    └── constant/
```

### 2.2 레이어 아키텍처

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│    (Controller, DTO, Exception)         │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│        Application Layer                │
│    (Service, Event Handler)             │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│          Domain Layer                   │
│    (Entity, Domain Event, Port)         │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│       Infrastructure Layer              │
│  (Repository, Redis, External API)      │
└─────────────────────────────────────────┘
```

---

## 3. 도메인 모델 설계

### 3.1 ERD (Entity Relationship Diagram)

```
┌─────────────────────┐
│   User              │
│─────────────────────│
│ id (PK)             │
│ username            │
│ email               │
│ created_at          │
└─────────────────────┘
         │ 1
         │
         │ N
┌─────────────────────┐         ┌─────────────────────┐
│   Payment           │   1:N   │   Refund            │
│─────────────────────│◄────────│─────────────────────│
│ id (PK)             │         │ id (PK)             │
│ user_id (FK)        │         │ payment_id (FK)     │
│ amount              │         │ refund_amount       │
│ payment_method_type │         │ reason              │
│ status              │         │ status              │
│ pg_transaction_id   │         │ refunded_at         │
│ created_at          │         │ created_at          │
│ updated_at          │         └─────────────────────┘
└─────────────────────┘
         │ 1
         │
         │ 1
┌─────────────────────┐
│   Subscription      │
│─────────────────────│
│ id (PK)             │
│ user_id (FK)        │
│ payment_id (FK)     │
│ billing_cycle       │
│ next_billing_date   │
│ status              │
│ created_at          │
│ cancelled_at        │
└─────────────────────┘


┌─────────────────────┐         ┌─────────────────────────┐
│   CookieWallet      │   1:N   │   CookieTransaction     │
│─────────────────────│◄────────│─────────────────────────│
│ id (PK)             │         │ id (PK)                 │
│ user_id (FK)        │         │ user_id (FK)            │
│ balance             │         │ transaction_type        │
│ version (낙관적락)   │         │ amount                  │
│ created_at          │         │ balance_after           │
│ updated_at          │         │ payment_id (FK) null    │
└─────────────────────┘         │ created_at              │
                                └─────────────────────────┘
```

### 3.2 주요 엔티티 상세

#### Payment (결제)
```java
@Entity
@Table(name = "payments", indexes = {
    @Index(name = "idx_user_created", columnList = "user_id, created_at"),
    @Index(name = "idx_status", columnList = "status")
})
public class Payment extends BaseEntity {
    @Id @GeneratedValue
    private Long id;
    
    private Long userId;
    private Long amount;
    
    @Enumerated(EnumType.STRING)
    private PaymentStatus status; // PENDING, SUCCESS, FAILED, CANCELLED
    
    @Enumerated(EnumType.STRING)
    private PaymentMethodType paymentMethodType; // CREDIT_CARD, BANK_TRANSFER, SIMPLE_PAY
    
    private String pgTransactionId; // PG사 거래 ID
    
    // 결제 수단 정보 (JSON 또는 별도 테이블)
    @Column(columnDefinition = "TEXT")
    private String paymentMethodInfo;
}
```

#### CookieWallet (쿠키 지갑)
```java
@Entity
@Table(name = "cookie_wallets", indexes = {
    @Index(name = "idx_user", columnList = "user_id", unique = true)
})
public class CookieWallet extends BaseEntity {
    @Id @GeneratedValue
    private Long id;
    
    @Column(nullable = false, unique = true)
    private Long userId;
    
    @Column(nullable = false)
    private Long balance;
    
    @Version  // 낙관적 락
    private Long version;
    
    public void charge(Long amount) {
        this.balance += amount;
    }
    
    public void use(Long amount) {
        if (this.balance < amount) {
            throw new InsufficientCookieException();
        }
        this.balance -= amount;
    }
}
```

### 3.3 Enum 정의

```java
public enum PaymentStatus {
    PENDING,    // 결제 대기
    SUCCESS,    // 결제 완료
    FAILED,     // 결제 실패
    CANCELLED   // 결제 취소
}

public enum PaymentMethodType {
    CREDIT_CARD,      // 신용카드
    BANK_TRANSFER,    // 계좌이체
    SIMPLE_PAY        // 간편결제
}

public enum SubscriptionStatus {
    ACTIVE,    // 활성
    PAUSED,    // 일시정지
    CANCELLED  // 해지
}

public enum CookieTransactionType {
    CHARGE,  // 충전
    USE,     // 사용
    REFUND   // 환불
}
```

---

## 4. 주요 플로우 다이어그램

### 4.1 일반 결제 플로우

```
[사용자]           [API]              [PaymentService]      [PG Mock]        [CookieService]
   │                 │                       │                   │                  │
   │─ 결제 요청 ────►│                       │                   │                  │
   │                 │─ createPayment() ───►│                   │                  │
   │                 │                       │                   │                  │
   │                 │                       │◄─ 분산 락 획득 ───┤ (Redis Lock)    │
   │                 │                       │                   │                  │
   │                 │                       │─ 중복 결제 체크 ─►│                  │
   │                 │                       │                   │                  │
   │                 │                       │─ Payment 생성 ───►│ (PENDING)       │
   │                 │                       │   (status=PENDING) │                 │
   │                 │                       │                   │                  │
   │                 │◄─ paymentId 반환 ────│                   │                  │
   │◄─ 201 Created ──│                       │                   │                  │
   │                 │                       │                   │                  │
   │─ 결제 실행 ────►│                       │                   │                  │
   │                 │─ processPayment() ──►│                   │                  │
   │                 │                       │─ PG 결제 요청 ───►│                  │
   │                 │                       │◄─ 결제 승인 ──────│                  │
   │                 │                       │                   │                  │
   │                 │                       │─ @Transactional ─┐│                  │
   │                 │                       │  status=SUCCESS  ││                  │
   │                 │                       │                  ││                  │
   │                 │                       │─ Event 발행 ─────┼┼─────────────────►│
   │                 │                       │  (PaymentCompleted)                   │
   │                 │                       │                  ││                  │
   │                 │                       │                  ││─ chargeCookie()─►│
   │                 │                       │                  ││                  │
   │                 │                       │◄─ 커밋 ──────────┘│                  │
   │                 │                       │                   │                  │
   │                 │                       │─ 분산 락 해제 ───►│                  │
   │                 │◄─ 결제 완료 ─────────│                   │                  │
   │◄─ 200 OK ───────│                       │                   │                  │
```

**핵심 포인트:**
1. Redis 분산 락으로 동일 사용자의 중복 결제 방지
2. Payment 상태를 PENDING → SUCCESS로 변경
3. 이벤트 기반으로 쿠키 충전 처리 (트랜잭션 내)
4. 모든 작업이 하나의 트랜잭션으로 원자성 보장

### 4.2 쿠키 사용 플로우 (동시성 제어)

```
[사용자A]          [API]           [CookieService]      [CookieWallet]     [Database]
   │                 │                    │                    │                │
   │─ 쿠키 사용 ───►│                    │                    │                │
   │  (100 쿠키)     │─ useCookie() ────►│                    │                │
   │                 │                    │                    │                │
   │                 │                    │─ @Transactional ─►│                │
   │                 │                    │                    │                │
   │                 │                    │─ findByUserId() ──┼──────────────►│
   │                 │                    │◄─ Wallet(v=1) ────┼────────────────│
   │                 │                    │                    │                │
   │                 │                    │─ wallet.use(100) ─►│                │
   │                 │                    │   balance 차감     │                │
   │                 │                    │                    │                │
   │                 │                    │─ save(wallet) ────┼──────────────►│
   │                 │                    │   version=2        │                │
   │                 │                    │                    │   UPDATE ... WHERE
   │                 │                    │                    │   id=? AND version=1
   │                 │                    │                    │                │

[사용자B - 동시 요청]
   │                 │                    │                    │                │
   │─ 쿠키 사용 ───►│                    │                    │                │
   │  (100 쿠키)     │─ useCookie() ────►│                    │                │
   │                 │                    │                    │                │
   │                 │                    │─ @Transactional ─►│                │
   │                 │                    │                    │                │
   │                 │                    │─ findByUserId() ──┼──────────────►│
   │                 │                    │◄─ Wallet(v=1) ────┼────────────────│
   │                 │                    │                    │  (아직 v=1 읽음)
   │                 │                    │─ wallet.use(100) ─►│                │
   │                 │                    │                    │                │
   │                 │                    │─ save(wallet) ────┼──────────────►│
   │                 │                    │   version=2        │                │
   │                 │                    │                    │   UPDATE ... WHERE
   │                 │                    │                    │   id=? AND version=1
   │                 │                    │                    │                │
   │                 │                    │◄─ 0 rows updated ─┼────────────────│
   │                 │                    │   (OptimisticLockException!)        │
   │                 │                    │                    │                │
   │                 │                    │─ 재시도 (1/3) ───►│                │
   │                 │                    │─ findByUserId() ──┼──────────────►│
   │                 │                    │◄─ Wallet(v=2) ────┼────────────────│
   │                 │                    │─ wallet.use(100) ─►│                │
   │                 │                    │─ save(wallet) ────┼──────────────►│
   │                 │                    │   version=3 성공   │                │
   │                 │◄─ 성공 ───────────│                    │                │
   │◄─ 200 OK ───────│                    │                    │                │
```

**핵심 포인트:**
1. `@Version`을 통한 낙관적 락 적용
2. 동시 요청 시 한 쪽은 OptimisticLockException 발생
3. 재시도 로직으로 최대 3회까지 재시도
4. 지수 백오프로 재시도 간격 증가

### 4.3 정기결제(구독) 플로우

```
[스케줄러]      [SubscriptionService]    [PaymentService]    [CookieService]
   │                    │                       │                   │
   │─ 매일 00시 실행 ──►│                       │                   │
   │                    │                       │                   │
   │                    │─ 오늘 결제할 구독 조회 │                   │
   │                    │   (next_billing_date  │                   │
   │                    │    = today)           │                   │
   │                    │                       │                   │
   │                    │─ for each subscription│                   │
   │                    │                       │                   │
   │                    │─ processSubscription()│                   │
   │                    │                       │                   │
   │                    │─────────────────────►│                   │
   │                    │   createPayment()     │                   │
   │                    │                       │                   │
   │                    │◄─ 결제 완료 ──────────│──────────────────►│
   │                    │                       │   쿠키 충전       │
   │                    │                       │                   │
   │                    │─ 다음 결제일 갱신     │                   │
   │                    │   next_billing_date   │                   │
   │                    │   += billing_cycle    │                   │
   │                    │                       │                   │
   │                    │─ 결제 실패 시         │                   │
   │                    │   retry_count++       │                   │
   │                    │   (최대 3회)          │                   │
   │                    │                       │                   │
   │                    │   3회 실패 시         │                   │
   │                    │   status=PAUSED       │                   │
   │                    │   알림 발송           │                   │
```

### 4.4 환불 플로우 (보상 트랜잭션)

```
[사용자]        [API]           [RefundService]      [PaymentService]    [CookieService]
   │              │                    │                     │                   │
   │─ 환불 요청 ─►│                    │                     │                   │
   │              │─ requestRefund() ─►│                     │                   │
   │              │                    │                     │                   │
   │              │                    │─ 환불 가능 검증 ───►│                   │
   │              │                    │   - 이미 환불됐나?   │                   │
   │              │                    │   - 결제 완료 상태?  │                   │
   │              │                    │                     │                   │
   │              │                    │─ @Transactional ───┐│                   │
   │              │                    │                    ││                   │
   │              │                    │─ Refund 생성 ──────┤│                   │
   │              │                    │                    ││                   │
   │              │                    │─ Payment.cancel() ─┤│                   │
   │              │                    │   status=CANCELLED ││                   │
   │              │                    │                    ││                   │
   │              │                    │─ Event 발행 ───────┼┼──────────────────►│
   │              │                    │  (PaymentCancelled)││                   │
   │              │                    │                    ││  쿠키 차감         │
   │              │                    │                    ││  (낙관적 락)       │
   │              │                    │                    ││                   │
   │              │                    │◄─ 커밋 ────────────┘│                   │
   │              │                    │                     │                   │
   │              │                    │─ PG 환불 요청 ─────►│                   │
   │              │                    │                     │                   │
   │              │◄─ 환불 완료 ───────│                     │                   │
   │◄─ 200 OK ────│                    │                     │                   │
   │              │                     │                    │                   │
   │              │                     │                    │                   │
   │         [환불 실패 시 보상 트랜잭션]                    │                   │
   │              │                     │                    │                   │
   │              │                    │─ PG 환불 실패 ─────►│                   │
   │              │                    │                     │                   │
   │              │                    │─ @Transactional ───┐│                   │
   │              │                    │                    ││                   │
   │              │                    │─ Payment 원복 ─────┤│                   │
   │              │                    │   status=SUCCESS   ││                   │
   │              │                    │                    ││                   │
   │              │                    │─ Refund 실패 처리 ─┤│                   │
   │              │                    │   status=FAILED    ││                   │
   │              │                    │                    ││                   │
   │              │                    │─ Event 발행 ───────┼┼──────────────────►│
   │              │                    │  (RefundFailed)    ││                   │
   │              │                    │                    ││  쿠키 재충전       │
   │              │                    │                    ││                   │
   │              │                    │◄─ 커밋 ────────────┘│                   │
```

**핵심 포인트:**
1. 환불 시 Payment 취소 + 쿠키 차감이 하나의 트랜잭션
2. PG 환불 실패 시 보상 트랜잭션으로 상태 원복
3. 이벤트 기반으로 쿠키 차감/재충전 처리

---

## 5. 동시성 제어 전략

### 5.1 Redis 분산 락 (결제 중복 방지)

```
┌─────────────────────────────────────────────────┐
│             Redis Distributed Lock              │
├─────────────────────────────────────────────────┤
│                                                  │
│  Lock Key: payment:lock:{userId}:{paymentType}  │
│                                                  │
│  Wait Time: 5초 (락 획득 대기 시간)              │
│  Lease Time: 10초 (락 자동 해제 시간)            │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Thread 1: Lock 획득 성공                │   │
│  │  ├─ 결제 중복 체크                       │   │
│  │  ├─ Payment 생성                         │   │
│  │  └─ Lock 해제                            │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
│  ┌──────────────────────────────────────────┐   │
│  │  Thread 2: Lock 획득 실패 (대기 중)      │   │
│  │  └─ 5초 후 타임아웃                      │   │
│  │     └─ LockAcquisitionException 발생     │   │
│  └──────────────────────────────────────────┘   │
│                                                  │
└─────────────────────────────────────────────────┘
```

**장점:**
- 분산 환경에서도 동작
- 명시적인 타임아웃 제어
- 데드락 방지 (자동 해제)

**단점:**
- Redis 장애 시 서비스 영향
- 네트워크 지연 가능성

### 5.2 낙관적 락 (쿠키 사용)

```
┌─────────────────────────────────────────────────┐
│          Optimistic Lock (JPA @Version)         │
├─────────────────────────────────────────────────┤
│                                                  │
│  CookieWallet: {id: 1, balance: 1000, version: 5}
│                                                  │
│  Transaction 1              Transaction 2       │
│  ┌────────────┐             ┌────────────┐      │
│  │ Read v=5   │             │ Read v=5   │      │
│  │ balance-=100│            │ balance-=50│      │
│  │            │             │            │      │
│  │ UPDATE ... │             │ UPDATE ... │      │
│  │ WHERE v=5  │             │ WHERE v=5  │      │
│  │ SET v=6    │             │ SET v=6    │      │
│  │            │             │            │      │
│  │ ✓ 성공     │             │ ✗ 실패     │      │
│  │ (1 row)    │             │ (0 rows)   │      │
│  └────────────┘             └────────────┘      │
│                                    │             │
│                             OptimisticLockException
│                                    │             │
│                              ┌────────────┐      │
│                              │ 재시도 1/3 │      │
│                              │ Read v=6   │      │
│                              │ balance-=50│      │
│                              │ UPDATE v=7 │      │
│                              │ ✓ 성공     │      │
│                              └────────────┘      │
│                                                  │
└─────────────────────────────────────────────────┘
```

**장점:**
- 높은 처리량 (TPS)
- 충돌이 적을 때 성능 우수
- 데드락 없음

**단점:**
- 충돌 시 재시도 필요
- 충돌이 많으면 성능 저하

---

## 6. 기술 스택

### 6.1 Backend
- **Language**: Java 17
- **Framework**: Spring Boot 3.2.x
- **ORM**: Spring Data JPA (Hibernate)
- **Query**: QueryDSL
- **Validation**: Spring Validation (Bean Validation)

### 6.2 Database
- **RDBMS**: MySQL 8.0 or PostgreSQL 14
- **Cache/Lock**: Redis 7.x
- **Migration**: Flyway or Liquibase

### 6.3 Library
- **Distributed Lock**: Redisson
- **Testing**: JUnit 5, Mockito, TestContainers
- **API Docs**: SpringDoc OpenAPI (Swagger)
- **Logging**: SLF4J + Logback

### 6.4 Monitoring (선택)
- **Metrics**: Micrometer + Prometheus
- **Tracing**: Spring Cloud Sleuth (or OpenTelemetry)

---

## 7. 트랜잭션 전파 전략

### 7.1 기본 원칙
```java
@Service
public class PaymentService {
    
    // 신규 트랜잭션 시작 (기본)
    @Transactional(propagation = Propagation.REQUIRED)
    public Payment processPayment(Long paymentId) {
        // 결제 처리 + 쿠키 충전
        // 하나라도 실패하면 전체 롤백
    }
    
    // 읽기 전용 (성능 최적화)
    @Transactional(readOnly = true)
    public Payment getPayment(Long paymentId) {
        return paymentRepository.findById(paymentId)
            .orElseThrow();
    }
}
```

### 7.2 이벤트 기반 트랜잭션
```java
@Service
public class PaymentEventHandler {
    
    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void handlePaymentCompleted(PaymentCompletedEvent event) {
        // 부모 트랜잭션 커밋 후 실행
        // 알림 발송, 로깅 등
    }
    
    @TransactionalEventListener(phase = TransactionPhase.BEFORE_COMMIT)
    public void chargeCookie(PaymentCompletedEvent event) {
        // 부모 트랜잭션에 참여
        // 쿠키 충전 (실패 시 전체 롤백)
    }
}
```

---

## 8. API 설계

### 8.1 결제 API

| Method | Endpoint | Description | 인증 |
|--------|----------|-------------|------|
| POST | /api/v1/payments | 결제 생성 | Required |
| POST | /api/v1/payments/{id}/process | 결제 실행 | Required |
| POST | /api/v1/payments/{id}/cancel | 결제 취소 | Required |
| GET | /api/v1/payments/{id} | 결제 조회 | Required |
| GET | /api/v1/payments | 결제 목록 조회 | Required |

### 8.2 쿠키 API

| Method | Endpoint | Description | 인증 |
|--------|----------|-------------|------|
| GET | /api/v1/cookies/balance | 잔액 조회 | Required |
| POST | /api/v1/cookies/use | 쿠키 사용 | Required |
| GET | /api/v1/cookies/transactions | 거래 이력 | Required |

### 8.3 구독 API

| Method | Endpoint | Description | 인증 |
|--------|----------|-------------|------|
| POST | /api/v1/subscriptions | 구독 생성 | Required |
| GET | /api/v1/subscriptions/{id} | 구독 조회 | Required |
| DELETE | /api/v1/subscriptions/{id} | 구독 취소 | Required |

### 8.4 환불 API

| Method | Endpoint | Description | 인증 |
|--------|----------|-------------|------|
| POST | /api/v1/refunds | 환불 요청 | Required |
| GET | /api/v1/refunds/{id} | 환불 조회 | Required |

---

## 9. 에러 처리 전략

### 9.1 에러 응답 구조
```json
{
  "timestamp": "2025-01-31T10:30:00",
  "status": 409,
  "error": "CONFLICT",
  "code": "PAYMENT_DUPLICATE",
  "message": "동일한 결제 요청이 처리 중입니다.",
  "path": "/api/v1/payments"
}
```

### 9.2 주요 에러 코드

| HTTP Status | Error Code | Description |
|-------------|------------|-------------|
| 400 | INVALID_REQUEST | 잘못된 요청 |
| 404 | PAYMENT_NOT_FOUND | 결제 정보 없음 |
| 409 | PAYMENT_DUPLICATE | 중복 결제 |
| 409 | INSUFFICIENT_COOKIE | 쿠키 잔액 부족 |
| 409 | ALREADY_REFUNDED | 이미 환불됨 |
| 500 | PG_ERROR | PG 연동 오류 |
| 503 | LOCK_ACQUISITION_FAILED | 락 획득 실패 |

---

## 10. 보안 고려사항

### 10.1 인증/인가
- Spring Security + JWT
- API 호출 시 Bearer 토큰 필수
- 사용자별 권한 체크

### 10.2 데이터 보안
- 민감 정보 암호화 (카드 번호, 계좌 번호)
- HTTPS 통신 강제
- SQL Injection 방지 (PreparedStatement)

### 10.3 Rate Limiting
- Bucket4j를 통한 API 호출 제한
- 사용자당 1분에 10회 결제 요청 제한

---

## 11. 성능 최적화 전략

### 11.1 캐싱
- 쿠키 잔액 조회 Redis 캐싱 (TTL: 10초)
- 결제 정보 조회 캐싱

### 11.2 인덱스 전략
```sql
-- 결제 목록 조회 최적화
CREATE INDEX idx_user_created ON payments(user_id, created_at DESC);

-- 쿠키 거래 이력 조회 최적화
CREATE INDEX idx_user_created ON cookie_transactions(user_id, created_at DESC);

-- 구독 정기결제 조회 최적화
CREATE INDEX idx_next_billing ON subscriptions(next_billing_date, status);
```

### 11.3 N+1 문제 해결
- Fetch Join 활용
- @EntityGraph 사용

---

## 12. 확장 가능성

### 12.1 결제 수단 확장
```java
public interface PaymentMethodStrategy {
    PaymentResult process(PaymentRequest request);
    PaymentResult cancel(String pgTransactionId);
}

@Component
public class CreditCardPaymentStrategy implements PaymentMethodStrategy {
    // 신용카드 결제 로직
}

@Component
public class BankTransferPaymentStrategy implements PaymentMethodStrategy {
    // 계좌이체 결제 로직
}
```

### 12.2 이벤트 기반 확장
- 결제 완료 → 포인트 적립, 이메일 발송, 통계 수집
- 쿠키 사용 → 사용 분석, 추천 시스템

### 12.3 마이크로서비스 전환 가능
- 현재: Monolithic (모듈화)
- 향후: Payment Service / Cookie Service 분리
- 이벤트 버스 (Kafka, RabbitMQ) 도입

---

## 13. 모니터링 지표

### 13.1 비즈니스 메트릭
- 결제 성공률 (%)
- 평균 결제 금액
- 쿠키 사용 빈도
- 환불율

### 13.2 기술 메트릭
- API 응답 시간 (P50, P95, P99)
- Redis 락 획득 시간
- 낙관적 락 충돌률
- DB 커넥션 풀 사용률

### 13.3 알림 임계값
- 결제 실패율 5% 이상
- API 응답 시간 1초 이상
- Redis 락 타임아웃 1분에 10회 이상

---

## 14. 테스트 전략

### 14.1 테스트 피라미드
```
        ┌─────────────┐
        │   E2E (5%)  │
        ├─────────────┤
        │ Integration │
        │    (25%)    │
        ├─────────────┤
        │    Unit     │
        │    (70%)    │
        └─────────────┘
```

### 14.2 주요 테스트 케이스
1. **동시성 테스트**
    - 동시 결제 요청 (분산 락)
    - 동시 쿠키 사용 (낙관적 락)

2. **트랜잭션 테스트**
    - 결제 실패 시 롤백
    - 환불 시 보상 트랜잭션

3. **성능 테스트**
    - 1000 TPS 부하 테스트
    - 쿠키 사용 처리 시간 측정

---

## 15. 배포 전략

### 15.1 환경 구성
- **Local**: H2 + Embedded Redis
- **Dev**: MySQL + Redis (Docker Compose)
- **Prod**: AWS RDS + ElastiCache (예정)

### 15.2 CI/CD
- GitHub Actions
- 테스트 자동화
- 코드 커버리지 80% 이상 유지

---

## 부록: 주요 참고 자료

1. **동시성 제어**
    - [Redisson Documentation](https://github.com/redisson/redisson)
    - JPA Optimistic Locking

2. **트랜잭션 패턴**
    - Saga Pattern
    - Event Sourcing

3. **테스트**
    - TestContainers
    - Concurrent Testing Patterns