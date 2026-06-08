-- ============================================================================
-- View: workspace.gold.gold_hospitality_skills
-- Layer: GOLD
-- Description: Hospitality industry specific skill demand analysis
-- ============================================================================
-- Purpose: Gold analytical view for gold_hospitality_skills
-- Dependencies: workspace.warehouse.bridge_job_skill, workspace.warehouse.dim_sector
-- Expected Output: Aggregated metrics with 6 columns
-- ============================================================================

CREATE OR REPLACE VIEW workspace.gold.gold_hospitality_skills AS
WITH hospitality_jobs AS (
  SELECT
    f.job_sk,
    f.posting_date_sk AS trend_date_sk
  FROM workspace.warehouse.fact_job_postings f
  JOIN workspace.warehouse.dim_sector s ON f.sector_sk = s.sector_sk
  WHERE s.sector_name = 'Hospitality'
    AND f.active_flag = TRUE
),
skill_demand AS (
  SELECT
    bjs.skill_sk,
    hj.trend_date_sk,
    COUNT(*) AS job_count
  FROM workspace.warehouse.bridge_job_skill bjs
  JOIN hospitality_jobs hj ON bjs.job_sk = hj.job_sk
  GROUP BY bjs.skill_sk, hj.trend_date_sk
),
skill_ranks AS (
  SELECT
    skill_sk,
    trend_date_sk,
    job_count,
    ROW_NUMBER() OVER (PARTITION BY trend_date_sk ORDER BY job_count DESC) AS demand_rank
  FROM skill_demand
),
growth_calc AS (
  SELECT
    skill_sk,
    trend_date_sk,
    job_count,
    LAG(job_count, 30) OVER (PARTITION BY skill_sk ORDER BY trend_date_sk) AS job_count_30d_ago
  FROM skill_demand
)
SELECT
  sr.skill_sk,
  sr.trend_date_sk,
  sr.job_count,
  sr.demand_rank,
  CASE 
    WHEN gc.job_count_30d_ago > 0 
    THEN ((gc.job_count - gc.job_count_30d_ago) * 100.0 / gc.job_count_30d_ago)
    ELSE NULL
  END AS growth_rate,
  CURRENT_TIMESTAMP() AS updated_at
FROM skill_ranks sr
LEFT JOIN growth_calc gc 
  ON sr.skill_sk = gc.skill_sk 
  AND sr.trend_date_sk = gc.trend_date_sk

-- End of VIEW definition
