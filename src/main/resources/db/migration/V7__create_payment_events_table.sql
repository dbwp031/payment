-- ============================================
-- Flyway Migration: V7__create_payment_events_table
-- Description: 결제 이벤트 테이블 생성 (이벤트 소싱용, 선택 사항)
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
-- ============================================

-- 결제 이벤트 테이블 생성 (이벤트 소싱)
CREATE TABLE payment_events (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id BIGINT NOT NULL,
    aggregate_type VARCHAR(50) NOT NULL,
    event_type VARCHAR(100) NOT NULL,
    event_data JSONB NOT NULL,
    version INT NOT NULL,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- 인덱스 생성
CREATE INDEX idx_payment_events_aggregate ON payment_events (aggregate_type, aggregate_id, version);
CREATE INDEX idx_payment_events_event_type ON payment_events (event_type, created_at);
CREATE INDEX idx_payment_events_data ON payment_events USING GIN (event_data);

-- 컬럼 코멘트
COMMENT ON TABLE payment_events IS '결제 이벤트 (이벤트 소싱)';
COMMENT ON COLUMN payment_events.id IS '이벤트 ID';
COMMENT ON COLUMN payment_events.aggregate_id IS '집합 루트 ID (payment_id, subscription_id 등)';
COMMENT ON COLUMN payment_events.aggregate_type IS '집합 루트 타입: PAYMENT, SUBSCRIPTION';
COMMENT ON COLUMN payment_events.event_type IS '이벤트 타입: PaymentCreated, PaymentCompleted 등';
COMMENT ON COLUMN payment_events.event_data IS '이벤트 데이터 (JSONB)';
COMMENT ON COLUMN payment_events.version IS '이벤트 버전 (순서 보장)';
COMMENT ON COLUMN payment_events.created_at IS '이벤트 발생 일시';

-- Rollback: DROP TABLE payment_events;
