-- ============================================================
-- SHOPHO MIGRATION 009: Order history archive table
-- ============================================================
-- Stores completed/expired/cancelled/disputed orders that are
-- archived by the 48-hour cleanup job (archive_orders_job).
-- Images are denormalised into a JSONB array so they survive
-- the cascade-delete on the orders table.
-- ============================================================

CREATE TABLE order_history (
    id                    UUID              PRIMARY KEY,
    creator_id            UUID              NOT NULL,
    shipper_id            UUID,

    note                  TEXT              NOT NULL,
    gold_reward           NUMERIC(8,2)      NOT NULL,

    -- Ship location (copied verbatim from orders)
    ship_apartment_id     UUID,
    ship_location         ship_location_type NOT NULL,
    ship_building         VARCHAR(20),
    ship_floor            SMALLINT,
    ship_room             VARCHAR(20),

    validity_option       VARCHAR(20)       NOT NULL,
    expires_at            TIMESTAMPTZ       NOT NULL,
    status                order_status      NOT NULL,

    -- All order timestamps
    created_at            TIMESTAMPTZ       NOT NULL,
    updated_at            TIMESTAMPTZ       NOT NULL,
    accepted_at           TIMESTAMPTZ,
    delivering_at         TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ,
    cancelled_at          TIMESTAMPTZ,
    estimated_minutes     SMALLINT,
    estimated_delivery_at TIMESTAMPTZ,

    -- Denormalised images (from order_images, sorted by sort_order)
    -- Each element: {"id": "...", "storage_key": "...", "public_url": "...", "sort_order": 0}
    images                JSONB             NOT NULL DEFAULT '[]',

    archived_at           TIMESTAMPTZ       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_order_history_creator ON order_history(creator_id, archived_at DESC);
CREATE INDEX idx_order_history_shipper ON order_history(shipper_id, archived_at DESC)
    WHERE shipper_id IS NOT NULL;
CREATE INDEX idx_order_history_status  ON order_history(status, archived_at DESC);
