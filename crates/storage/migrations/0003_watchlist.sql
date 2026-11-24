-- =====================================================================
--  0003 : liste « À regarder » par compte (fixtures/README.md)
-- =====================================================================

CREATE TABLE watchlist (
    user_id  INTEGER NOT NULL REFERENCES user(id)  ON DELETE CASCADE,
    media_id INTEGER NOT NULL REFERENCES media(id) ON DELETE CASCADE,
    added_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    PRIMARY KEY (user_id, media_id)
);
