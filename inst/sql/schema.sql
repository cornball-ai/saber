CREATE TABLE IF NOT EXISTS terms (
  id        TEXT PRIMARY KEY,
  name      TEXT NOT NULL,
  filepath  TEXT,
  aliases   TEXT DEFAULT '[]',
  promoted  INTEGER DEFAULT 0,
  updated_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now'))
);

CREATE TABLE IF NOT EXISTS relations (
  subject_id    TEXT NOT NULL,
  relation_type TEXT NOT NULL,
  object_id     TEXT NOT NULL,
  confirmed     INTEGER DEFAULT 1,
  source        TEXT DEFAULT 'inline',
  PRIMARY KEY (subject_id, relation_type, object_id)
);

CREATE TABLE IF NOT EXISTS files (
  filepath  TEXT PRIMARY KEY,
  hash      TEXT,
  parsed_at TEXT DEFAULT (strftime('%Y-%m-%dT%H:%M:%S', 'now'))
);
