-- ============================================================
-- SHOPHO MIGRATION 010: Shipper browse-alert preferences
-- ============================================================
-- Each shipper can subscribe to push notifications for new
-- pending orders that match their saved browse filter.
-- ============================================================

CREATE TABLE shipper_alerts (
    user_id         UUID        PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    enabled         BOOLEAN     NOT NULL DEFAULT FALSE,
    apartment_ids   JSONB       NOT NULL DEFAULT '[]',  -- list of apt UUID strings
    building_keys   JSONB       NOT NULL DEFAULT '[]',  -- list of "apt_uuid:building_name"
    floors          JSONB       NOT NULL DEFAULT '[]',  -- list of int
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_shipper_alerts_enabled ON shipper_alerts(enabled) WHERE enabled = TRUE;
