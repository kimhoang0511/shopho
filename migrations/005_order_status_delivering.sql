-- ============================================================
-- SHOPHO MIGRATION 005: Add 'delivering' to order_status enum
-- ============================================================

ALTER TYPE order_status ADD VALUE IF NOT EXISTS 'delivering';
