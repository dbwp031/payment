-- ============================================
-- Flyway Migration: V9__insert_seed_data
-- Description: 테스트 데이터 삽입 (개발 환경 전용)
-- Author: System
-- Date: 2026-01-31
-- Database: PostgreSQL 14
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

-- 테스트 사용자 생성
-- password_hash는 'password123'을 BCrypt로 해싱한 값 (예시)
INSERT INTO users (username, email, password_hash, status) VALUES
('test_user_1', 'test1@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'ACTIVE'),
('test_user_2', 'test2@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'ACTIVE'),
('test_user_3', 'test3@example.com', '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy', 'INACTIVE');

-- 쿠키 지갑 초기화 (사용자 생성 시 함께 생성)
INSERT INTO cookie_wallets (user_id, balance, version) VALUES
(1, 1000, 0),
(2, 500, 0),
(3, 0, 0);

-- 테스트 결제 데이터
INSERT INTO payments (user_id, amount, payment_method_type, payment_method_info, status, pg_transaction_id, requested_at, completed_at) VALUES
(1, 10000, 'CREDIT_CARD', '{"card_number": "1234-****-****-5678", "card_type": "CREDIT", "installment": 0}', 'SUCCESS', 'PG_TXN_001', NOW(), NOW()),
(1, 5000, 'SIMPLE_PAY', '{"provider": "KAKAO_PAY"}', 'SUCCESS', 'PG_TXN_002', NOW(), NOW()),
(2, 20000, 'CREDIT_CARD', '{"card_number": "9876-****-****-5432", "card_type": "CREDIT", "installment": 3}', 'PENDING', NULL, NOW(), NULL);

-- 테스트 쿠키 거래 이력
INSERT INTO cookie_transactions (user_id, wallet_id, transaction_type, amount, balance_before, balance_after, payment_id, description) VALUES
(1, 1, 'CHARGE', 1000, 0, 1000, 1, '쿠키 충전 - 결제 완료'),
(2, 2, 'CHARGE', 500, 0, 500, 2, '쿠키 충전 - 결제 완료');

-- Rollback:
-- DELETE FROM cookie_transactions WHERE user_id IN (1, 2, 3);
-- DELETE FROM payments WHERE user_id IN (1, 2, 3);
-- DELETE FROM cookie_wallets WHERE user_id IN (1, 2, 3);
-- DELETE FROM users WHERE username LIKE 'test_user_%';
