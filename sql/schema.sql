-- Esquema de InstaBox (PostgreSQL)
-- Dos tablas relacionadas por event_id.

CREATE TABLE IF NOT EXISTS events (
    event_id    UUID PRIMARY KEY,
    client_name TEXT        NOT NULL,
    event_type  TEXT,
    event_date  DATE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS photos (
    photo_id     UUID PRIMARY KEY,
    event_id     UUID        NOT NULL REFERENCES events(event_id) ON DELETE CASCADE,
    message      TEXT,
    picture_key  TEXT        NOT NULL,   -- ruta del original reducido en S3 (pictures/)
    polaroid_key TEXT        NOT NULL,   -- ruta de la polaroid en S3 (polaroids/)
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Indice para acelerar el conteo y las consultas por evento.
CREATE INDEX IF NOT EXISTS idx_photos_event_id ON photos(event_id);
