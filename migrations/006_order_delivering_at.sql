-- ============================================================
-- SHOPHO MIGRATION 006: delivering_at timestamp + auto-complete proc
-- ============================================================

ALTER TABLE orders ADD COLUMN delivering_at TIMESTAMPTZ;

-- Auto-complete orders that have been in 'delivering' for > 1 hour.
-- Returns (order_id, shipper_id, gold_reward) for each completed order
-- so the caller can reward the shipper via the gold service.
CREATE OR REPLACE FUNCTION fn_autocomplete_delivering_orders()
RETURNS TABLE(order_id UUID, shipper_id UUID, gold_reward NUMERIC) AS $$
BEGIN
    RETURN QUERY
    UPDATE orders
    SET    status       = 'completed',
           completed_at = NOW()
    WHERE  status       = 'delivering'
      AND  delivering_at <= NOW() - INTERVAL '1 hour'
    RETURNING id, orders.shipper_id, orders.gold_reward;
END;
$$ LANGUAGE plpgsql;
