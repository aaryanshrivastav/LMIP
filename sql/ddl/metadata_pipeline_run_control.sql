-- ============================================================================
-- Table: workspace.metadata.pipeline_run_control
-- Layer: METADATA
-- Description: Pipeline execution control and orchestration metadata
-- ============================================================================
-- Purpose: Physical table definition for pipeline_run_control
-- Dependencies: None
-- Consumers: workspace.audit.audit_pipeline_runs
-- Expected Output: Table created with 10 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.metadata.pipeline_run_control (
  run_control_sk BIGINT NOT NULL COMMENT 'Surrogate key',
  pipeline_name STRING NOT NULL COMMENT 'Name of the pipeline',
  batch_id STRING NOT NULL COMMENT 'Unique batch identifier',
  source_name STRING COMMENT 'Source being processed',
  trigger_type STRING NOT NULL COMMENT 'Trigger type: SCHEDULED, MANUAL, EVENT',
  scheduled_at TIMESTAMP COMMENT 'Scheduled execution time',
  started_at TIMESTAMP COMMENT 'Actual start time',
  ended_at TIMESTAMP COMMENT 'Completion time',
  status STRING NOT NULL COMMENT 'Execution status: PENDING, RUNNING, SUCCESS, FAILED',
  operator_user STRING COMMENT 'User who triggered manual runs'
,
  PRIMARY KEY (run_control_sk),
  CONSTRAINT uq_batch_id UNIQUE (batch_id),
  CONSTRAINT chk_trigger_type CHECK (trigger_type IN ('SCHEDULED', 'MANUAL', 'EVENT')),
  CONSTRAINT chk_run_status CHECK (status IN ('PENDING', 'RUNNING', 'SUCCESS', 'FAILED'))
)
COMMENT 'Pipeline execution control and orchestration metadata'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
