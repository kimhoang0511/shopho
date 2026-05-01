-- ============================================================
-- SHOPHO MIGRATION 004: Computed delivery deadline on orders
-- ============================================================

ALTER TABLE orders ADD COLUMN estimated_delivery_at TIMESTAMPTZ;
