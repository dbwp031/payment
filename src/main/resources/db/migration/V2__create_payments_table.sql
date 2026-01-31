-- ============================================
-- Flyway Migration: V2__create_payments_table
-- Description: 결제 테이블 생성
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
-- ============================================

-- 결제 테이블 생성
CREATE TABLE payments (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    amount BIGINT NOT NULL,
    payment_method_type VARCHAR(30) NOT NULL,
    payment_method_info TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    pg_transaction_id VARCHAR(100),
    failure_reason VARCHAR(500),
    requested_at TIMESTAMP(6) NOT NULL,
    completed_at TIMESTAMP(6),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_payments_user_created ON payments (user_id, created_at DESC);
CREATE INDEX idx_payments_user_status ON payments (user_id, status);
CREATE INDEX idx_payments_status_created ON payments (status, created_at DESC);
CREATE INDEX idx_payments_pg_transaction ON payments (pg_transaction_id);
CREATE INDEX idx_payments_completed_at ON payments (completed_at);

-- 컬럼 코멘트
COMMENT ON TABLE payments IS '결제';
COMMENT ON COLUMN payments.id IS '결제 ID';
COMMENT ON COLUMN payments.user_id IS '사용자 ID';
COMMENT ON COLUMN payments.amount IS '결제 금액 (원 단위, Long)';
COMMENT ON COLUMN payments.payment_method_type IS '결제 수단: CREDIT_CARD, BANK_TRANSFER, SIMPLE_PAY';
COMMENT ON COLUMN payments.payment_method_info IS '결제 수단 상세 정보 (JSON 형태)';
COMMENT ON COLUMN payments.status IS '상태: PENDING, SUCCESS, FAILED, CANCELLED';
COMMENT ON COLUMN payments.pg_transaction_id IS 'PG사 거래 ID';
COMMENT ON COLUMN payments.failure_reason IS '실패 사유';
COMMENT ON COLUMN payments.requested_at IS '결제 요청 일시';
COMMENT ON COLUMN payments.completed_at IS '결제 완료 일시';
COMMENT ON COLUMN payments.created_at IS '생성일시';
COMMENT ON COLUMN payments.updated_at IS '수정일시';

-- updated_at 트리거
CREATE TRIGGER update_payments_updated_at
    BEFORE UPDATE ON payments
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Rollback: DROP TABLE payments;
