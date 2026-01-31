-- ============================================
-- Flyway Migration: V6__create_cookie_transactions_table
-- Description: 쿠키 거래 이력 테이블 생성
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
-- ============================================

-- 쿠키 거래 이력 테이블 생성
CREATE TABLE cookie_transactions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    wallet_id BIGINT NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    amount BIGINT NOT NULL,
    balance_before BIGINT NOT NULL,
    balance_after BIGINT NOT NULL,
    payment_id BIGINT,
    reference_type VARCHAR(50),
    reference_id BIGINT,
    description VARCHAR(200),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_cookie_tx_user_created ON cookie_transactions (user_id, created_at DESC);
CREATE INDEX idx_cookie_tx_wallet_created ON cookie_transactions (wallet_id, created_at DESC);
CREATE INDEX idx_cookie_tx_type_created ON cookie_transactions (transaction_type, created_at DESC);
CREATE INDEX idx_cookie_tx_payment ON cookie_transactions (payment_id);
CREATE INDEX idx_cookie_tx_reference ON cookie_transactions (reference_type, reference_id);

-- 컬럼 코멘트
COMMENT ON TABLE cookie_transactions IS '쿠키 거래 이력';
COMMENT ON COLUMN cookie_transactions.id IS '거래 ID';
COMMENT ON COLUMN cookie_transactions.user_id IS '사용자 ID';
COMMENT ON COLUMN cookie_transactions.wallet_id IS '지갑 ID';
COMMENT ON COLUMN cookie_transactions.transaction_type IS '거래 유형: CHARGE, USE, REFUND';
COMMENT ON COLUMN cookie_transactions.amount IS '거래 금액';
COMMENT ON COLUMN cookie_transactions.balance_before IS '거래 전 잔액';
COMMENT ON COLUMN cookie_transactions.balance_after IS '거래 후 잔액';
COMMENT ON COLUMN cookie_transactions.payment_id IS '관련 결제 ID (충전/환불 시)';
COMMENT ON COLUMN cookie_transactions.reference_type IS '참조 타입: ORDER, SERVICE 등';
COMMENT ON COLUMN cookie_transactions.reference_id IS '참조 ID (주문 ID, 서비스 ID 등)';
COMMENT ON COLUMN cookie_transactions.description IS '거래 설명';
COMMENT ON COLUMN cookie_transactions.created_at IS '거래일시';

-- Rollback: DROP TABLE cookie_transactions;
