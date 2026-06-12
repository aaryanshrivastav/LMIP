-- ============================================================================
-- Table: workspace.audit.audit_pipeline_runs
-- Layer: AUDIT
-- Description: Audit log of all pipeline executions for monitoring and compliance
-- ============================================================================
-- Purpose: Physical table definition for audit_pipeline_runs
-- Dependencies: None
-- Consumers: workspace.warehouse.fact_pipeline_runs
-- Expected Output: Table created with 9 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.audit.audit_pipeline_runs (
  audit_run_id STRING NOT NULL COMMENT 'Audit record ID',
  run_id STRING NOT NULL COMMENT 'Pipeline run ID',
  pipeline_name STRING NOT NULL COMMENT 'Pipeline name',
  run_timestamp TIMESTAMP NOT NULL COMMENT 'Run start time',
  run_duration_seconds INT COMMENT 'Duration in seconds',
  status STRING NOT NULL COMMENT 'SUCCESS, FAILED, PARTIAL',
  records_processed BIGINT COMMENT 'Total records processed',
  error_message STRING COMMENT 'Error details if failed',
  logged_at TIMESTAMP NOT NULL COMMENT 'Audit log timestamp'
,
  PRIMARY KEY (audit_run_id),
  CONSTRAINT chk_status CHECK (status IN ('SUCCESS', 'FAILED', 'PARTIAL'))
)
COMMENT 'Audit log of all pipeline executions for monitoring and compliance'
PARTITIONED BY (DATE(run_timestamp))
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
