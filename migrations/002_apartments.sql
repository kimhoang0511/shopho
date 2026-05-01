-- ============================================================
-- SHOPHO MIGRATION 002: Apartments & Buildings
-- ============================================================

CREATE TABLE apartments (
    id          UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    name        VARCHAR(100) NOT NULL,
    address     TEXT        NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE apartment_buildings (
    id           UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    apartment_id UUID        NOT NULL REFERENCES apartments(id) ON DELETE CASCADE,
    name         VARCHAR(50) NOT NULL,   -- e.g. "CT1", "CT2", "A", "B"
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (apartment_id, name)
);

CREATE INDEX idx_apt_buildings_apartment ON apartment_buildings(apartment_id);

CREATE TRIGGER trg_apartments_updated_at
    BEFORE UPDATE ON apartments
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();
