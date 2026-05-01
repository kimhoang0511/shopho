-- ============================================================
-- SHOPHO MIGRATION 011: Performance indexes + stored-proc fixes
-- ============================================================

-- ── 1. gold_proposals ────────────────────────────────────────
-- Queries: WHERE order_id = ? ORDER BY proposed_gold DESC
-- The existing UniqueConstraint(order_id, proposer_id) helps WHERE,
-- but a dedicated index with proposed_gold supports ORDER BY too.
CREATE INDEX IF NOT EXISTS idx_gold_proposals_order
    ON gold_proposals(order_id, proposed_gold DESC);

-- ── 2. orders: market-prices query ───────────────────────────
-- Query: WHERE ship_apartment_id = ? AND ship_location = ?
--   AND status IN ('accepted','delivering','completed')
-- ORDER BY created_at DESC LIMIT 7
CREATE INDEX IF NOT EXISTS idx_orders_market_price
    ON orders(ship_apartment_id, ship_location, created_at DESC)
    WHERE status IN ('accepted', 'delivering', 'completed');

-- ── 3. orders: autocomplete background jobs ───────────────────
-- fn_autocomplete_delivering_orders:
--   WHERE status = 'delivering' AND delivering_at <= NOW() - INTERVAL '1 hour'
CREATE INDEX IF NOT EXISTS idx_orders_autocomplete_delivering
    ON orders(delivering_at)
    WHERE status = 'delivering';

-- fn_autocomplete_accepted_orders:
--   WHERE status = 'accepted' AND accepted_at <= NOW() - INTERVAL '12 hours'
CREATE INDEX IF NOT EXISTS idx_orders_autocomplete_accepted
    ON orders(accepted_at)
    WHERE status = 'accepted';

-- ── 4. Update stored procs to return creator_id ───────────────
-- Eliminates N+1 SELECT creator_id per row in Python background jobs.
-- Must DROP first because PostgreSQL disallows changing the return type
-- of an existing function via CREATE OR REPLACE.

DROP FUNCTION IF EXISTS fn_autocomplete_delivering_orders();

CREATE OR REPLACE FUNCTION fn_autocomplete_delivering_orders()
RETURNS TABLE(order_id UUID, shipper_id UUID, creator_id UUID, gold_reward NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    UPDATE orders
    SET    status       = 'completed',
           completed_at = NOW(),
           updated_at   = NOW()
    WHERE  status        = 'delivering'
      AND  delivering_at <= NOW() - INTERVAL '1 hour'
    RETURNING id, orders.shipper_id, orders.creator_id, orders.gold_reward;
END;
$$;

DROP FUNCTION IF EXISTS fn_autocomplete_accepted_orders();

CREATE OR REPLACE FUNCTION fn_autocomplete_accepted_orders()
RETURNS TABLE(order_id UUID, shipper_id UUID, creator_id UUID, gold_reward NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    UPDATE orders
    SET    status       = 'completed',
           completed_at = NOW(),
           updated_at   = NOW()
    WHERE  status      = 'accepted'
      AND  accepted_at <= NOW() - INTERVAL '12 hours'
    RETURNING id, orders.shipper_id, orders.creator_id, orders.gold_reward;
END;
$$;
