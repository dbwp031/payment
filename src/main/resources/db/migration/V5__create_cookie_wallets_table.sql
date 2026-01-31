-- ============================================
-- Flyway Migration: V5__create_cookie_wallets_table
-- Description: 쿠키 지갑 테이블 생성
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
-- ============================================

-- 쿠키 지갑 테이블 생성
CREATE TABLE cookie_wallets (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL,
    balance BIGINT NOT NULL DEFAULT 0,
    version BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT uk_cookie_wallets_user UNIQUE (user_id)
);

-- 컬럼 코멘트
COMMENT ON TABLE cookie_wallets IS '쿠키 지갑';
COMMENT ON COLUMN cookie_wallets.id IS '지갑 ID';
COMMENT ON COLUMN cookie_wallets.user_id IS '사용자 ID';
COMMENT ON COLUMN cookie_wallets.balance IS '쿠키 잔액';
COMMENT ON COLUMN cookie_wallets.version IS '낙관적 락 버전';
COMMENT ON COLUMN cookie_wallets.created_at IS '생성일시';
COMMENT ON COLUMN cookie_wallets.updated_at IS '수정일시';

-- updated_at 트리거
CREATE TRIGGER update_cookie_wallets_updated_at
    BEFORE UPDATE ON cookie_wallets
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();

-- Rollback: DROP TABLE cookie_wallets;
