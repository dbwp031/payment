-- ============================================
-- Flyway Migration: V8__add_check_constraints
-- Description: CHECK 제약조건 추가
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
-- ============================================

-- 결제 금액은 양수
ALTER TABLE payments
ADD CONSTRAINT chk_payments_amount_positive
CHECK (amount > 0);

-- 환불 금액은 양수
ALTER TABLE refunds
ADD CONSTRAINT chk_refunds_amount_positive
CHECK (refund_amount > 0);

-- 구독 금액은 양수
ALTER TABLE subscriptions
ADD CONSTRAINT chk_subscriptions_amount_positive
CHECK (amount > 0);

-- 쿠키 잔액은 음수 불가
ALTER TABLE cookie_wallets
ADD CONSTRAINT chk_balance_non_negative
CHECK (balance >= 0);

-- 쿠키 거래 금액은 양수
ALTER TABLE cookie_transactions
ADD CONSTRAINT chk_cookie_tx_amount_positive
CHECK (amount > 0);

-- 재시도 횟수 범위
ALTER TABLE subscriptions
ADD CONSTRAINT chk_retry_count
CHECK (retry_count >= 0 AND retry_count <= max_retry_count);

-- Rollback:
-- ALTER TABLE payments DROP CONSTRAINT chk_payments_amount_positive;
-- ALTER TABLE refunds DROP CONSTRAINT chk_refunds_amount_positive;
-- ALTER TABLE subscriptions DROP CONSTRAINT chk_subscriptions_amount_positive;
-- ALTER TABLE cookie_wallets DROP CONSTRAINT chk_balance_non_negative;
-- ALTER TABLE cookie_transactions DROP CONSTRAINT chk_cookie_tx_amount_positive;
-- ALTER TABLE subscriptions DROP CONSTRAINT chk_retry_count;
