-- ============================================================================
-- View: workspace.gold.gold_hospitality_hiring
-- Layer: GOLD
-- Description: Hospitality sector hiring trends and analysis
-- ============================================================================
-- Purpose: Gold analytical view for gold_hospitality_hiring
-- Dependencies: workspace.warehouse.fact_job_postings
-- Expected Output: Aggregated metrics with 6 columns
-- ============================================================================

CREATE OR REPLACE VIEW workspace.gold.gold_hospitality_hiring AS
WITH hospitality_metrics AS (
  SELECT
    f.posting_date_sk AS hiring_date_sk,
    COUNT(*) AS total_jobs,
    COUNT(CASE WHEN f.is_new_job = TRUE THEN 1 END) AS new_jobs,
    f.role_sk,
    AVG(dj.salary_max) AS avg_salary
  FROM workspace.warehouse.fact_job_postings f
  JOIN workspace.warehouse.dim_sector s ON f.sector_sk = s.sector_sk
  JOIN workspace.warehouse.dim_job dj ON f.job_sk = dj.job_sk AND dj.is_current = TRUE
  WHERE s.sector_name = 'Hospitality'
    AND f.active_flag = TRUE
  GROUP BY f.posting_date_sk, f.role_sk
),
top_role_by_date AS (
  SELECT
    hiring_date_sk,
    role_sk,
    total_jobs,
    ROW_NUMBER() OVER (PARTITION BY hiring_date_sk ORDER BY total_jobs DESC) AS rn
  FROM hospitality_metrics
)
SELECT
  hm.hiring_date_sk,
  SUM(hm.total_jobs) AS total_jobs,
  SUM(hm.new_jobs) AS new_jobs,
  r.role_name AS top_role,
  AVG(hm.avg_salary) AS avg_salary,
  CURRENT_TIMESTAMP() AS updated_at
FROM hospitality_metrics hm
LEFT JOIN top_role_by_date tr 
  ON hm.hiring_date_sk = tr.hiring_date_sk 
  AND tr.rn = 1
LEFT JOIN workspace.warehouse.dim_role r ON tr.role_sk = r.role_sk
GROUP BY hm.hiring_date_sk, r.role_name

-- End of VIEW definition
