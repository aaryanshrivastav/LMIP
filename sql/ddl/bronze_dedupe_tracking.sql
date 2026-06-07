-- ============================================================================
-- Table: workspace.bronze.dedupe_tracking
-- Layer: BRONZE
-- Description: Tracks duplicate payload occurrences in Bronze tables without deleting data
-- ============================================================================
-- Purpose: Physical table definition for dedupe_tracking
-- Dependencies: workspace.bronze.bronze_job_snapshot
-- Consumers: workspace.audit.audit_dq_results
-- Expected Output: Table created with 10 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.bronze.dedupe_tracking (
  dedupe_id STRING NOT NULL COMMENT 'Unique deduplication record ID',
  source_table STRING NOT NULL COMMENT 'Source table being deduplicated',
  batch_id STRING NOT NULL COMMENT 'Batch identifier',
  dedupe_key_hash STRING NOT NULL COMMENT 'Hash of deduplication key columns',
  first_seen_record_id STRING COMMENT 'First occurrence record ID',
  first_seen_batch_id STRING COMMENT 'Batch where first seen',
  duplicate_count INT NOT NULL COMMENT 'Number of duplicate occurrences',
  first_seen_timestamp TIMESTAMP COMMENT 'First occurrence timestamp',
  last_seen_timestamp TIMESTAMP COMMENT 'Last occurrence timestamp',
  tracking_timestamp TIMESTAMP NOT NULL COMMENT 'When dedupe was tracked'
,
  PRIMARY KEY (dedupe_id)
)
COMMENT 'Tracks duplicate payload occurrences in Bronze tables without deleting data'
PARTITIONED BY (tracking_timestamp)
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
