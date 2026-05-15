-- embedding_benchmark_tables.sql
-- Tablas de resultados para benchmark de modelos de embeddings.

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.embedding_benchmark_run (
    run_id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    source_table TEXT NOT NULL,
    sample_size INT NOT NULL,
    text_field TEXT NOT NULL,
    model_ids TEXT[] NOT NULL,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS analytics.embedding_benchmark_item (
    run_id BIGINT NOT NULL REFERENCES analytics.embedding_benchmark_run(run_id) ON DELETE CASCADE,
    model_id TEXT NOT NULL,
    ordinal INT NOT NULL,
    hu_group_id BIGINT NOT NULL,
    project_id BIGINT,
    partner_id BIGINT,
    text_char_len INT NOT NULL,
    text_word_len INT NOT NULL,
    embedding_dim INT NOT NULL,
    latency_ms NUMERIC(12,3) NOT NULL,
    l2_norm NUMERIC(18,8) NOT NULL,
    self_consistency_cosine NUMERIC(12,8) NOT NULL,
    PRIMARY KEY (run_id, model_id, ordinal)
);

CREATE TABLE IF NOT EXISTS analytics.embedding_benchmark_metric (
    run_id BIGINT NOT NULL REFERENCES analytics.embedding_benchmark_run(run_id) ON DELETE CASCADE,
    model_id TEXT NOT NULL,
    metric_name TEXT NOT NULL,
    metric_value NUMERIC(18,8) NOT NULL,
    PRIMARY KEY (run_id, model_id, metric_name)
);
