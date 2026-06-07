-- ============================================================================
-- Table: workspace.gold.gold_hospitality_hiring
-- Layer: GOLD
-- Description: Hospitality sector hiring trends and analysis
-- ============================================================================
-- Purpose: Physical table definition for gold_hospitality_hiring
-- Dependencies: workspace.warehouse.fact_job_postings
-- Expected Output: Table created with 6 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.gold.gold_hospitality_hiring (
  hiring_date_sk INT NOT NULL COMMENT 'Date key',
  total_jobs BIGINT COMMENT 'Total hospitality jobs',
  new_jobs BIGINT COMMENT 'New postings',
  top_role STRING COMMENT 'Most hired role',
  avg_salary DECIMAL(15,2) COMMENT 'Average salary',
  updated_at TIMESTAMP NOT NULL COMMENT 'Last refresh'
,
  PRIMARY KEY (hiring_date_sk)
)
COMMENT 'Hospitality sector hiring trends and analysis'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
