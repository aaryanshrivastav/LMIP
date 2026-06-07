-- ============================================================================
-- Table: workspace.gold.gold_skill_demand
-- Layer: GOLD
-- Description: Skill demand analytics showing most requested skills and trends
-- ============================================================================
-- Purpose: Physical table definition for gold_skill_demand
-- Dependencies: workspace.warehouse.bridge_job_skill, workspace.warehouse.fact_job_postings
-- Expected Output: Table created with 8 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.gold.gold_skill_demand (
  skill_sk BIGINT NOT NULL COMMENT 'Skill key',
  demand_date_sk INT NOT NULL COMMENT 'Date key',
  job_count BIGINT COMMENT 'Jobs requiring skill',
  company_count BIGINT COMMENT 'Companies requiring skill',
  avg_salary_usd DECIMAL(15,2) COMMENT 'Average salary for skill',
  growth_rate_30d DECIMAL(10,2) COMMENT '30-day growth rate',
  top_sector STRING COMMENT 'Primary sector demanding skill',
  updated_at TIMESTAMP NOT NULL COMMENT 'Last refresh'
,
  PRIMARY KEY (skill_sk, demand_date_sk)
)
COMMENT 'Skill demand analytics showing most requested skills and trends'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
