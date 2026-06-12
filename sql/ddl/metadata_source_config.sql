-- ============================================================================
-- Table: workspace.metadata.source_config
-- Layer: METADATA
-- Description: Configuration registry for external data sources
-- ============================================================================
-- Purpose: Physical table definition for source_config
-- Dependencies: None
-- Consumers: workspace.warehouse.dim_source
-- Expected Output: Table created with 9 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.metadata.source_config (
  source_config_sk BIGINT NOT NULL COMMENT 'Surrogate key',
  source_name STRING NOT NULL COMMENT 'Unique source identifier',
  source_type STRING NOT NULL COMMENT 'API type: REST, GraphQL, etc.',
  endpoint_url STRING NOT NULL COMMENT 'Base API endpoint URL',
  auth_ref STRING COMMENT 'Reference to authentication credentials',
  active_flag BOOLEAN NOT NULL COMMENT 'Is this source currently active',
  page_size INT COMMENT 'Default page size for pagination',
  rate_limit_policy STRING COMMENT 'Rate limiting configuration (JSON)',
  notes STRING COMMENT 'Additional notes about the source'
,
  PRIMARY KEY (source_config_sk),
  CONSTRAINT uq_source_name UNIQUE (source_name)
)
COMMENT 'Configuration registry for external data sources'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
