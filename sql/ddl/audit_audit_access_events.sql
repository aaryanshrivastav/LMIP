-- ============================================================================
-- Table: workspace.audit.audit_access_events
-- Layer: AUDIT
-- Description: Audit log of data access events for security and compliance
-- ============================================================================
-- Purpose: Physical table definition for audit_access_events
-- Dependencies: None
-- Consumers: None (audit/compliance use)
-- Expected Output: Table created with 9 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.audit.audit_access_events (
  access_event_id STRING NOT NULL COMMENT 'Access event ID',
  user_id STRING NOT NULL COMMENT 'User identifier',
  user_email STRING COMMENT 'User email',
  access_timestamp TIMESTAMP NOT NULL COMMENT 'Access time',
  resource_type STRING NOT NULL COMMENT 'TABLE, VIEW, NOTEBOOK',
  resource_name STRING NOT NULL COMMENT 'Resource accessed',
  action STRING NOT NULL COMMENT 'SELECT, INSERT, UPDATE, DELETE',
  rows_affected BIGINT COMMENT 'Rows read/modified',
  status STRING NOT NULL COMMENT 'SUCCESS, DENIED, ERROR'
,
  PRIMARY KEY (access_event_id),
  CONSTRAINT chk_access_status CHECK (status IN ('SUCCESS', 'DENIED', 'ERROR'))
)
COMMENT 'Audit log of data access events for security and compliance'
PARTITIONED BY (DATE(access_timestamp))
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
