-- ============================================================================
-- Table: workspace.quarantine.quarantine_batches
-- Layer: QUARANTINE
-- Description: Batch-level tracking for bulk quarantine operations
-- ============================================================================
-- Purpose: Physical table definition for quarantine_batches
-- Dependencies: workspace.quarantine.quarantine_jobs
-- Consumers: workspace.gold.gold_pipeline_health, workspace.audit.audit_pipeline_runs
-- Expected Output: Table created with 20 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.quarantine.quarantine_batches (
  batch_id STRING NOT NULL COMMENT 'Unique identifier for this batch operation',
  operation_type STRING NOT NULL COMMENT 'Type of batch operation: ROUTE, REPROCESS, DISCARD, CLEANUP, REVIEW_APPLY',
  source_notebook STRING NOT NULL COMMENT 'Notebook path that executed this batch operation',
  initiated_by STRING COMMENT 'User or service account that triggered the batch operation',
  operation_status STRING NOT NULL COMMENT 'Overall status: IN_PROGRESS, COMPLETED, FAILED, PARTIALLY_COMPLETED',
  records_processed BIGINT NOT NULL COMMENT 'Total number of records included in this batch',
  records_succeeded BIGINT NOT NULL COMMENT 'Number of records successfully processed',
  records_failed BIGINT NOT NULL COMMENT 'Number of records that failed processing',
  failure_stage STRING COMMENT 'Pipeline stage where batch failure occurred',
  failure_reason STRING COMMENT 'Detailed error message or reason for batch failure',
  source_layer STRING COMMENT 'Originating data layer for quarantined records',
  dq_rule_name STRING COMMENT 'Data quality rule that triggered quarantine',
  severity STRING COMMENT 'Severity level: ERROR, WARN',
  reprocess_target_table STRING COMMENT 'Target table for reprocessing',
  retention_days INT COMMENT 'Retention period applied for CLEANUP operations',
  review_file_path STRING COMMENT 'Path to CSV file containing bulk review decisions',
  batch_config STRING COMMENT 'JSON string containing additional configuration parameters',
  execution_duration_seconds DOUBLE COMMENT 'Total execution time in seconds',
  started_at TIMESTAMP NOT NULL COMMENT 'Timestamp when batch operation started',
  completed_at TIMESTAMP COMMENT 'Timestamp when batch operation completed',
  created_at TIMESTAMP NOT NULL COMMENT 'Timestamp when batch record was created'
,
  PRIMARY KEY (batch_id),
  CONSTRAINT chk_batch_operation_type CHECK (operation_type IN ('ROUTE', 'REPROCESS', 'DISCARD', 'CLEANUP', 'REVIEW_APPLY')),
  CONSTRAINT chk_batch_operation_status CHECK (operation_status IN ('IN_PROGRESS', 'COMPLETED', 'FAILED', 'PARTIALLY_COMPLETED'))
)
COMMENT 'Batch-level tracking for bulk quarantine operations'
PARTITIONED BY (DATE(started_at))
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
