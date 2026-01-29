-- Example tables; replace with real geocodebr exports
CREATE TABLE IF NOT EXISTS geocode_logradouro (
    id SERIAL PRIMARY KEY,
    nome TEXT,
    geom geometry(Point, 4326)
);

-- Add indexes for performance
CREATE INDEX IF NOT EXISTS idx_geocode_logradouro_nome ON geocode_logradouro(nome);
