-- ============================================================
-- SHOPHO MIGRATION 007: Auto-complete accepted orders after 12h
-- ============================================================

CREATE OR REPLACE FUNCTION fn_autocomplete_accepted_orders()
RETURNS TABLE(order_id UUID, shipper_id UUID, gold_reward NUMERIC) AS $$
BEGIN
    RETURN QUERY
    UPDATE orders
    SET    status       = 'completed',
           completed_at = NOW()
    WHERE  status       = 'accepted'
      AND  accepted_at <= NOW() - INTERVAL '12 hours'
    RETURNING id, orders.shipper_id, orders.gold_reward;
END;
$$ LANGUAGE plpgsql;
