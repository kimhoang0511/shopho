-- ============================================================
-- SHOPHO DATABASE SCHEMA
-- PostgreSQL 14+  |  Host: localhost:5433  |  DB: shopho_db
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";   -- fuzzy text search on notes

-- ────────────────────────────────────────────────────────────
-- ENUM TYPES
-- ────────────────────────────────────────────────────────────

CREATE TYPE order_status AS ENUM (
    'pending',      -- Đang chờ người nhận ship
    'accepted',     -- Đã có người nhận ship
    'completed',    -- hoàn thành
    'cancelled',    -- Người tạo huỷ
    'expired'       -- Hết hiệu lực
);

CREATE TYPE ship_location_type AS ENUM (
    'building',   -- Tại toà
    'floor',      -- Tại tầng
    'room'        -- Tại phòng
);

CREATE TYPE gold_tx_type AS ENUM (
    'top_up',          -- Nạp gold
    'order_lock',      -- Khoá gold khi tạo đơn
    'order_reward',    -- Trả gold cho người ship
    'order_refund',    -- Hoàn gold khi đơn expired/cancelled
    'withdrawal'       -- Rút gold
);

-- ────────────────────────────────────────────────────────────
-- USERS
-- ────────────────────────────────────────────────────────────

CREATE TABLE users (
    id               UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    username         VARCHAR(50) UNIQUE NOT NULL,
    email            VARCHAR(255) UNIQUE,
    phone            VARCHAR(20)  UNIQUE,
    password_hash    TEXT         NOT NULL,
    display_name     VARCHAR(100),
    avatar_url       TEXT,

    -- Gold balance (atomic, never goes negative – enforced by trigger)
    gold_balance     NUMERIC(12,2) NOT NULL DEFAULT 100.00
                         CHECK (gold_balance >= 0),

    -- Apartment location
    apt_building     VARCHAR(20),   -- Toà: A, B, C…
    apt_floor        SMALLINT,      -- Tầng: 1–100
    apt_room         VARCHAR(20),   -- Phòng: 1001, 2B…

    is_active        BOOLEAN NOT NULL DEFAULT TRUE,
    is_verified      BOOLEAN NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at     TIMESTAMPTZ
);

-- ────────────────────────────────────────────────────────────
-- ORDERS
-- ────────────────────────────────────────────────────────────

CREATE TABLE orders (
    id               UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    creator_id       UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    shipper_id       UUID         REFERENCES users(id) ON DELETE SET NULL,

    -- Content
    note             TEXT         NOT NULL,
    gold_reward      NUMERIC(8,2) NOT NULL CHECK (gold_reward > 0),

    -- Ship location
    ship_location    ship_location_type NOT NULL,
    ship_building    VARCHAR(20),   -- Toà đến
    ship_floor       SMALLINT,      -- Tầng đến (nếu floor/room)
    ship_room        VARCHAR(20),   -- Phòng đến  (nếu room)

    -- Validity
    -- Accepted values: '7_min','15_min','30_min','1_hour','3_hours','6_hours','12_hours'
    validity_option  VARCHAR(20)  NOT NULL,
    expires_at       TIMESTAMPTZ  NOT NULL,

    status           order_status NOT NULL DEFAULT 'pending',

    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at      TIMESTAMPTZ,
    completed_at     TIMESTAMPTZ,
    cancelled_at     TIMESTAMPTZ
);

-- Ensure only one shipper can accept (DB-level race-condition guard)
CREATE UNIQUE INDEX uq_order_shipper
    ON orders(id)
    WHERE status = 'accepted';

-- ────────────────────────────────────────────────────────────
-- ORDER IMAGES
-- ────────────────────────────────────────────────────────────

CREATE TABLE order_images (
    id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id     UUID        NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    storage_key  TEXT        NOT NULL,   -- MinIO / S3 object key
    public_url   TEXT        NOT NULL,
    sort_order   SMALLINT    NOT NULL DEFAULT 0,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- GOLD LEDGER  (append-only, source of truth)
-- ────────────────────────────────────────────────────────────

CREATE TABLE gold_ledger (
    id               UUID         PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id         UUID         REFERENCES orders(id) ON DELETE SET NULL,
    tx_type          gold_tx_type NOT NULL,
    -- Positive = credit to user, Negative = debit from user
    amount           NUMERIC(12,2) NOT NULL,
    balance_after    NUMERIC(12,2) NOT NULL,
    description      TEXT,
    -- Prevents duplicate transactions (e.g. retried requests)
    idempotency_key  VARCHAR(128) UNIQUE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- DEVICE TOKENS  (FCM / APNs for push notifications)
-- ────────────────────────────────────────────────────────────

CREATE TABLE device_tokens (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       TEXT        NOT NULL,
    platform    VARCHAR(10) NOT NULL CHECK (platform IN ('ios','android','macos','web')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, token)
);

-- ────────────────────────────────────────────────────────────
-- NOTIFICATIONS  (in-app)
-- ────────────────────────────────────────────────────────────

CREATE TABLE notifications (
    id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    order_id   UUID        REFERENCES orders(id) ON DELETE CASCADE,
    type       VARCHAR(50) NOT NULL,
    title      VARCHAR(255) NOT NULL,
    body       TEXT        NOT NULL,
    is_read    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ────────────────────────────────────────────────────────────
-- REFRESH TOKENS
-- ────────────────────────────────────────────────────────────

CREATE TABLE refresh_tokens (
    id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT        NOT NULL UNIQUE,
    device_id  TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked    BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ════════════════════════════════════════════════════════════
-- INDEXES  (performance critical)
-- ════════════════════════════════════════════════════════════

-- Hot path: list pending orders (shippers browsing)
CREATE INDEX idx_orders_pending_building
    ON orders(ship_building, created_at DESC)
    WHERE status = 'pending';

-- Expiry background job: find orders to expire
CREATE INDEX idx_orders_expires
    ON orders(expires_at)
    WHERE status = 'pending';

-- User's own order history
CREATE INDEX idx_orders_creator
    ON orders(creator_id, created_at DESC);

CREATE INDEX idx_orders_shipper
    ON orders(shipper_id, created_at DESC)
    WHERE shipper_id IS NOT NULL;

-- Gold ledger per user
CREATE INDEX idx_gold_ledger_user
    ON gold_ledger(user_id, created_at DESC);

-- Unread notifications
CREATE INDEX idx_notifications_unread
    ON notifications(user_id, is_read, created_at DESC)
    WHERE is_read = FALSE;

-- Full-text search on order notes
CREATE INDEX idx_orders_note_trgm
    ON orders USING GIN (note gin_trgm_ops)
    WHERE status = 'pending';

-- ════════════════════════════════════════════════════════════
-- TRIGGERS
-- ════════════════════════════════════════════════════════════

-- Auto-update updated_at columns
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- Prevent gold_balance going negative (second line of defence after app-level check)
CREATE OR REPLACE FUNCTION fn_guard_gold_balance()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.gold_balance < 0 THEN
        RAISE EXCEPTION 'Insufficient gold balance (user: %)', NEW.id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guard_gold_balance
    BEFORE UPDATE OF gold_balance ON users
    FOR EACH ROW EXECUTE FUNCTION fn_guard_gold_balance();

-- ════════════════════════════════════════════════════════════
-- STORED PROCEDURES  (used by background job)
-- ════════════════════════════════════════════════════════════

-- Called every 30s by the Python scheduler; returns IDs of newly-expired orders
-- so the app can broadcast WebSocket events and refund gold.
CREATE OR REPLACE FUNCTION fn_expire_pending_orders()
RETURNS TABLE(expired_order_id UUID, creator_id UUID, gold_reward NUMERIC)
LANGUAGE plpgsql AS $$
BEGIN
    RETURN QUERY
    UPDATE orders
    SET    status = 'expired', updated_at = NOW()
    WHERE  status    = 'pending'
      AND  expires_at <= NOW()
    RETURNING id, orders.creator_id, orders.gold_reward;
END;
$$;

-- ════════════════════════════════════════════════════════════
-- SEED DATA (dev only)
-- ════════════════════════════════════════════════════════════

-- Default admin user  (password: Admin@123 – change before prod)
INSERT INTO users (username, email, password_hash, display_name, apt_building, apt_floor, apt_room, gold_balance, is_verified)
VALUES (
    'admin',
    'admin@shopho.local',
    '$2b$12$placeholder_hash_change_me',
    'Admin',
    'A', 1, '101',
    9999.00,
    TRUE
) ON CONFLICT DO NOTHING;
