-- ============================================================================
-- Table: workspace.gold.gold_hospitality_skills
-- Layer: GOLD
-- Description: Hospitality industry specific skill demand analysis
-- ============================================================================
-- Purpose: Physical table definition for gold_hospitality_skills
-- Dependencies: workspace.warehouse.bridge_job_skill, workspace.warehouse.dim_sector
-- Expected Output: Table created with 6 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.gold.gold_hospitality_skills (
  skill_sk BIGINT NOT NULL COMMENT 'Skill key',
  trend_date_sk INT NOT NULL COMMENT 'Date key',
  job_count BIGINT COMMENT 'Jobs requiring skill',
  demand_rank INT COMMENT 'Skill demand rank',
  growth_rate DECIMAL(10,2) COMMENT 'Growth rate',
  updated_at TIMESTAMP NOT NULL COMMENT 'Last refresh'
,
  PRIMARY KEY (skill_sk, trend_date_sk)
)
COMMENT 'Hospitality industry specific skill demand analysis'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
