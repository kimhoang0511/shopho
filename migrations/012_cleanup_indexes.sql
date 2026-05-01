-- ============================================================
-- SHOPHO MIGRATION 012: Indexes for data-cleanup background jobs
-- ============================================================

-- ── 1. notifications: full listing (unread + read, newest first) ──
-- The existing idx_notifications_unread covers (user_id, is_read, created_at DESC)
-- but only indexes WHERE is_read = FALSE.  Listing ALL notifications for a user
-- (e.g. notification history screen) needs a plain (user_id, created_at DESC) index.
CREATE INDEX IF NOT EXISTS idx_notifications_user_time
    ON notifications(user_id, created_at DESC);

-- ── 2. notifications: bulk delete of old read notifications ──────
-- cleanup_stale_data_job: WHERE is_read = TRUE AND created_at < NOW() - 90 days
CREATE INDEX IF NOT EXISTS idx_notifications_cleanup
    ON notifications(created_at)
    WHERE is_read = TRUE;

-- ── 3. refresh_tokens: bulk delete of expired / revoked tokens ───
-- cleanup_stale_data_job:
--   WHERE expires_at < NOW() - 90 days
--   OR (revoked = TRUE AND created_at < NOW() - 7 days)
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires
    ON refresh_tokens(expires_at);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_revoked
    ON refresh_tokens(created_at)
    WHERE revoked = TRUE;
