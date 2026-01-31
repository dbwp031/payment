-- ============================================
-- Flyway Migration: V4__create_subscriptions_table
-- Description: 정기결제(구독) 테이블 생성
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
-- ============================================

-- 정기결제(구독) 테이블 생성
CREATE TABLE subscriptions (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    initial_payment_id BIGINT,
    amount BIGINT NOT NULL,
    billing_cycle VARCHAR(20) NOT NULL,
    next_billing_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    retry_count INT NOT NULL DEFAULT 0,
    max_retry_count INT NOT NULL DEFAULT 3,
    last_billed_at TIMESTAMP(6),
    cancelled_at TIMESTAMP(6),
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_subscriptions_user_status ON subscriptions (user_id, status);
CREATE INDEX idx_subscriptions_next_billing ON subscriptions (next_billing_date, status);
CREATE INDEX idx_subscriptions_status ON subscriptions (status);

-- 컬럼 코멘트
COMMENT ON TABLE subscriptions IS '정기결제(구독)';
COMMENT ON COLUMN subscriptions.id IS '구독 ID';
COMMENT ON COLUMN subscriptions.user_id IS '사용자 ID';
COMMENT ON COLUMN subscriptions.initial_payment_id IS '최초 결제 ID';
COMMENT ON COLUMN subscriptions.amount IS '구독 금액 (월/년)';
COMMENT ON COLUMN subscriptions.billing_cycle IS '결제 주기: MONTHLY, YEARLY';
COMMENT ON COLUMN subscriptions.next_billing_date IS '다음 결제 예정일';
COMMENT ON COLUMN subscriptions.status IS '상태: ACTIVE, PAUSED, CANCELLED';
COMMENT ON COLUMN subscriptions.retry_count IS '결제 실패 재시도 횟수';
COMMENT ON COLUMN subscriptions.max_retry_count IS '최대 재시도 횟수';
COMMENT ON COLUMN subscriptions.last_billed_at IS '마지막 결제 성공 일시';
COMMENT ON COLUMN subscriptions.cancelled_at IS '구독 취소 일시';
COMMENT ON COLUMN subscriptions.created_at IS '생성일시';
COMMENT ON COLUMN subscriptions.updated_at IS '수정일시';

-- updated_at 트리거
CREATE TRIGGER update_subscriptions_updated_at
    BEFORE UPDATE ON subscriptions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Rollback: DROP TABLE subscriptions;
