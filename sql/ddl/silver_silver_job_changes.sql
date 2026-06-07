-- ============================================================================
-- Table: workspace.silver.silver_job_changes
-- Layer: SILVER
-- Description: Change data capture log tracking all modifications to job postings over time
-- ============================================================================
-- Purpose: Physical table definition for silver_job_changes
-- Dependencies: workspace.silver.silver_jobs_current
-- Consumers: workspace.warehouse.fact_job_lifecycle, workspace.audit.audit_dq_results
-- Expected Output: Table created with 8 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.silver.silver_job_changes (
  change_id STRING NOT NULL COMMENT 'Unique change event ID',
  enterprise_job_id STRING NOT NULL COMMENT 'Job identifier',
  change_type STRING NOT NULL COMMENT 'INSERT, UPDATE, DELETE, RESTORE',
  change_timestamp TIMESTAMP NOT NULL COMMENT 'When change occurred',
  changed_fields ARRAY<STRING> COMMENT 'List of changed fields',
  old_hash STRING COMMENT 'Previous record hash',
  new_hash STRING NOT NULL COMMENT 'New record hash',
  batch_id STRING NOT NULL COMMENT 'Processing batch ID'
,
  PRIMARY KEY (change_id)
)
COMMENT 'Change data capture log tracking all modifications to job postings over time'
PARTITIONED BY (change_timestamp)
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
