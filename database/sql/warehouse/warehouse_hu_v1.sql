-- warehouse_hu_v1.sql
-- DDL warehouse HU v1

CREATE SCHEMA IF NOT EXISTS analytics;

CREATE TABLE IF NOT EXISTS analytics.wh_hu_group (
    group_id BIGINT PRIMARY KEY,
    project_id BIGINT,
    partner_id BIGINT,
    root_id BIGINT,
    node_count INT NOT NULL,
    max_depth INT NOT NULL,
    min_create_date TIMESTAMP,
    max_write_date TIMESTAMP,
    sum_allocated_hours NUMERIC(12,2),
    sum_effective_hours NUMERIC(12,2),
    sum_remaining_hours NUMERIC(12,2),
    sum_total_hours_spent NUMERIC(12,2),
    avg_progress NUMERIC(5,2),
    done_nodes INT NOT NULL DEFAULT 0,
    in_progress_nodes INT NOT NULL DEFAULT 0,
    canceled_nodes INT NOT NULL DEFAULT 0,
    helpdesk_ticket_ids BIGINT[],
    sale_order_ids BIGINT[],
    sale_line_ids BIGINT[],
    owner_user_ids BIGINT[],
    assignee_user_ids BIGINT[],
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS analytics.wh_hu_node (
    node_id BIGINT PRIMARY KEY,
    group_id BIGINT NOT NULL,
    parent_id BIGINT,
    project_id BIGINT,
    partner_id BIGINT,
    depth INT,
    state TEXT,
    active BOOLEAN,
    priority TEXT,
    owner_user_id BIGINT,
    assignee_user_ids BIGINT[],
    allocated_hours NUMERIC(12,2),
    effective_hours NUMERIC(12,2),
    remaining_hours NUMERIC(12,2),
    total_hours_spent NUMERIC(12,2),
    progress NUMERIC(5,2),
    helpdesk_ticket_id BIGINT,
    sale_order_id BIGINT,
    sale_line_id BIGINT,
    create_date TIMESTAMP,
    write_date TIMESTAMP,
    description_raw TEXT,
    description_clean TEXT,
    is_container BOOLEAN,
    is_functional BOOLEAN,
    has_feature BOOLEAN,
    has_scenario BOOLEAN,
    has_gwt BOOLEAN,
    is_deleted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_wh_hu_node_group
      FOREIGN KEY (group_id)
      REFERENCES analytics.wh_hu_group(group_id)
);

CREATE TABLE IF NOT EXISTS analytics.wh_hu_embedding_input (
    group_id BIGINT NOT NULL,
    embedding_type TEXT NOT NULL,
    embedding_text TEXT NOT NULL,
    project_id BIGINT,
    partner_id BIGINT,
    embedded_at TIMESTAMP NOT NULL,
    meta JSONB NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_wh_hu_embedding_input PRIMARY KEY (group_id, embedding_type),
    CONSTRAINT fk_wh_hu_embedding_input_group
      FOREIGN KEY (group_id)
      REFERENCES analytics.wh_hu_group(group_id),
    CONSTRAINT ck_wh_hu_embedding_input_type
      CHECK (embedding_type IN ('full', 'solution', 'hu_description'))
);

CREATE TABLE IF NOT EXISTS analytics.wh_etl_watermark (
    process_name TEXT PRIMARY KEY,
    last_max_write_date TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_wh_hu_group_project_id ON analytics.wh_hu_group(project_id);
CREATE INDEX IF NOT EXISTS idx_wh_hu_group_partner_id ON analytics.wh_hu_group(partner_id);
CREATE INDEX IF NOT EXISTS idx_wh_hu_group_max_write_date ON analytics.wh_hu_group(max_write_date);
CREATE INDEX IF NOT EXISTS idx_wh_hu_group_is_deleted ON analytics.wh_hu_group(is_deleted);

CREATE INDEX IF NOT EXISTS idx_wh_hu_node_group_id ON analytics.wh_hu_node(group_id);
CREATE INDEX IF NOT EXISTS idx_wh_hu_node_write_date ON analytics.wh_hu_node(write_date);
CREATE INDEX IF NOT EXISTS idx_wh_hu_node_project_id ON analytics.wh_hu_node(project_id);
CREATE INDEX IF NOT EXISTS idx_wh_hu_node_partner_id ON analytics.wh_hu_node(partner_id);
CREATE INDEX IF NOT EXISTS idx_wh_hu_node_is_deleted ON analytics.wh_hu_node(is_deleted);

CREATE INDEX IF NOT EXISTS idx_wh_hu_embedding_input_type ON analytics.wh_hu_embedding_input(embedding_type);
CREATE INDEX IF NOT EXISTS idx_wh_hu_embedding_input_project_partner ON analytics.wh_hu_embedding_input(project_id, partner_id);
