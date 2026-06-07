-- ============================================================================
-- Table: workspace.gold.gold_location_trends
-- Layer: GOLD
-- Description: Geographic hiring trends and location-based analytics
-- ============================================================================
-- Purpose: Physical table definition for gold_location_trends
-- Dependencies: workspace.warehouse.fact_job_postings, workspace.warehouse.dim_location
-- Expected Output: Table created with 8 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.gold.gold_location_trends (
  location_sk BIGINT NOT NULL COMMENT 'Location key',
  trend_date_sk INT NOT NULL COMMENT 'Date key',
  total_jobs BIGINT COMMENT 'Total jobs in location',
  remote_jobs BIGINT COMMENT 'Remote job count',
  onsite_jobs BIGINT COMMENT 'Onsite job count',
  avg_salary_usd DECIMAL(15,2) COMMENT 'Average salary',
  top_sector STRING COMMENT 'Dominant sector',
  updated_at TIMESTAMP NOT NULL COMMENT 'Last refresh'
,
  PRIMARY KEY (location_sk, trend_date_sk)
)
COMMENT 'Geographic hiring trends and location-based analytics'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
