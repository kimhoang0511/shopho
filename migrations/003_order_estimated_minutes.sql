-- ============================================================
-- SHOPHO MIGRATION 003: Estimated delivery minutes on orders
-- ============================================================

ALTER TABLE orders ADD COLUMN estimated_minutes SMALLINT;
