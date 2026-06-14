-- ============================================================================
-- Table: workspace.semantic.sem_company_map
-- Layer: SEMANTIC
-- Description: Company to sector mapping and company enrichment data
-- ============================================================================
-- Purpose: Physical table definition for sem_company_map
-- Dependencies: workspace.semantic.sem_company_canonical
-- Consumers: workspace.warehouse.dim_company
-- Expected Output: Table created with 5 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.semantic.sem_company_map (
  canonical_company_name STRING NOT NULL COMMENT 'Canonical company name',
  sector_name STRING COMMENT 'Assigned sector',
  sector_assignment_method STRING COMMENT 'How sector was assigned',
  sector_confidence DECIMAL(5,4) COMMENT 'Sector assignment confidence',
  updated_at TIMESTAMP NOT NULL COMMENT 'Last update timestamp'
,
  PRIMARY KEY (canonical_company_name)
)
COMMENT 'Company to sector mapping and company enrichment data'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
