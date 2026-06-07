-- ============================================================================
-- Table: workspace.gold.gold_hospitality_companies
-- Layer: GOLD
-- Description: Hospitality companies hiring activity
-- ============================================================================
-- Purpose: Physical table definition for gold_hospitality_companies
-- Dependencies: workspace.warehouse.fact_job_postings, workspace.warehouse.dim_company
-- Expected Output: Table created with 5 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.gold.gold_hospitality_companies (
  company_sk BIGINT NOT NULL COMMENT 'Company key',
  active_jobs BIGINT COMMENT 'Current active jobs',
  total_jobs_30d BIGINT COMMENT 'Jobs last 30 days',
  top_role STRING COMMENT 'Most hired role',
  updated_at TIMESTAMP NOT NULL COMMENT 'Last refresh'
,
  PRIMARY KEY (company_sk)
)
COMMENT 'Hospitality companies hiring activity'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
