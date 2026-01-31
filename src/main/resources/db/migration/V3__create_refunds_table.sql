-- ============================================
-- Flyway Migration: V3__create_refunds_table
-- Description: 환불 테이블 생성
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
-- ============================================

-- 환불 테이블 생성
CREATE TABLE refunds (
    id BIGSERIAL PRIMARY KEY,
    payment_id BIGINT NOT NULL,
    user_id BIGINT NOT NULL,
    refund_amount BIGINT NOT NULL,
    reason VARCHAR(500),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    pg_refund_id VARCHAR(100),
    failure_reason VARCHAR(500),
    refunded_at TIMESTAMP(6),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_refunds_payment ON refunds (payment_id);
CREATE INDEX idx_refunds_user_created ON refunds (user_id, created_at DESC);
CREATE INDEX idx_refunds_status ON refunds (status);

-- 컬럼 코멘트
COMMENT ON TABLE refunds IS '환불';
COMMENT ON COLUMN refunds.id IS '환불 ID';
COMMENT ON COLUMN refunds.payment_id IS '원본 결제 ID';
COMMENT ON COLUMN refunds.user_id IS '사용자 ID';
COMMENT ON COLUMN refunds.refund_amount IS '환불 금액';
COMMENT ON COLUMN refunds.reason IS '환불 사유';
COMMENT ON COLUMN refunds.status IS '상태: PENDING, SUCCESS, FAILED';
COMMENT ON COLUMN refunds.pg_refund_id IS 'PG사 환불 거래 ID';
COMMENT ON COLUMN refunds.failure_reason IS '환불 실패 사유';
COMMENT ON COLUMN refunds.refunded_at IS '환불 완료 일시';
COMMENT ON COLUMN refunds.created_at IS '생성일시';
COMMENT ON COLUMN refunds.updated_at IS '수정일시';

-- updated_at 트리거
CREATE TRIGGER update_refunds_updated_at
    BEFORE UPDATE ON refunds
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Rollback: DROP TABLE refunds;
