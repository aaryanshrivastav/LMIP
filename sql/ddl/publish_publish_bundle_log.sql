-- ============================================================================
-- Table: workspace.publish.publish_bundle_log
-- Layer: PUBLISH
-- Description: Log of bundle delivery attempts to external systems
-- ============================================================================
-- Purpose: Physical table definition for publish_bundle_log
-- Dependencies: workspace.publish.publish_manifest
-- Consumers: None (audit/monitoring use)
-- Expected Output: Table created with 7 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.publish.publish_bundle_log (
  bundle_log_id STRING NOT NULL COMMENT 'Unique log entry identifier',
  manifest_id STRING NOT NULL COMMENT 'FK to publish_manifest',
  target_system STRING NOT NULL COMMENT 'Destination system identifier',
  target_location STRING COMMENT 'Destination path or endpoint',
  status STRING NOT NULL COMMENT 'Delivery status: PENDING, IN_PROGRESS, DELIVERED, FAILED',
  created_at TIMESTAMP NOT NULL COMMENT 'When delivery was initiated'
,
  PRIMARY KEY (bundle_log_id),
  CONSTRAINT chk_bundle_status CHECK (status IN ('PENDING', 'IN_PROGRESS', 'DELIVERED', 'FAILED'))
)
COMMENT 'Log of bundle delivery attempts to external systems'
PARTITIONED BY (DATE(created_at))
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
