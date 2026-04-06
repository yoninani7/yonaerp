-- ============================================================
--  BGT Auth — helper tables
--  Run these alongside your existing system_users table.
-- ============================================================

-- Tracks failed login attempts per user (for rate-limiting / lockout)
CREATE TABLE IF NOT EXISTS login_attempts (
    user_id         INT UNSIGNED    NOT NULL,
    attempt_count   TINYINT UNSIGNED NOT NULL DEFAULT 1,
    last_attempt_at DATETIME        NOT NULL DEFAULT CURRENT_TIMESTAMP
                                    ON UPDATE CURRENT_TIMESTAMP,

    PRIMARY KEY (user_id),
    CONSTRAINT fk_attempt_user
        FOREIGN KEY (user_id) REFERENCES system_users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Stores "remember me" tokens (hashed SHA-256) for persistent sessions
CREATE TABLE IF NOT EXISTS remember_tokens (
    token_id    INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    user_id     INT UNSIGNED    NOT NULL,
    token_hash  CHAR(64)        NOT NULL,   -- SHA-256 hex = always 64 chars
    expires_at  DATETIME        NOT NULL,
    created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (token_id),
    UNIQUE  KEY uk_token_hash (token_hash),
    INDEX       idx_rt_user   (user_id),
    INDEX       idx_rt_expiry (expires_at),

    CONSTRAINT fk_rt_user
        FOREIGN KEY (user_id) REFERENCES system_users(user_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Optional: scheduled cleanup of expired remember tokens
-- (run via cron or MySQL Event Scheduler)
-- DELETE FROM remember_tokens WHERE expires_at < NOW();
