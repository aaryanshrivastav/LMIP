-- ============================================================================
-- View: workspace.gold.gold_hospitality_companies
-- Layer: GOLD
-- Description: Hospitality companies hiring activity
-- ============================================================================
-- Purpose: Gold analytical view for gold_hospitality_companies
-- Dependencies: workspace.warehouse.fact_job_postings, workspace.warehouse.dim_company
-- Expected Output: Aggregated metrics with 5 columns
-- ============================================================================

CREATE OR REPLACE VIEW workspace.gold.gold_hospitality_companies AS
WITH hospitality_company_jobs AS (
  SELECT
    f.company_sk,
    COUNT(CASE WHEN f.active_flag = TRUE THEN 1 END) AS active_jobs,
    COUNT(CASE WHEN f.is_new_job = TRUE AND DATEDIFF(DAY, f.posting_timestamp, CURRENT_TIMESTAMP()) <= 30 THEN 1 END) AS total_jobs_30d,
    f.role_sk,
    COUNT(*) AS role_count
  FROM workspace.warehouse.fact_job_postings f
  JOIN workspace.warehouse.dim_sector s ON f.sector_sk = s.sector_sk
  WHERE s.sector_name = 'Hospitality'
  GROUP BY f.company_sk, f.role_sk
),
top_role_per_company AS (
  SELECT
    company_sk,
    role_sk,
    role_count,
    ROW_NUMBER() OVER (PARTITION BY company_sk ORDER BY role_count DESC) AS rn
  FROM hospitality_company_jobs
)
SELECT
  hcj.company_sk,
  SUM(hcj.active_jobs) AS active_jobs,
  SUM(hcj.total_jobs_30d) AS total_jobs_30d,
  r.role_name AS top_role,
  CURRENT_TIMESTAMP() AS updated_at
FROM hospitality_company_jobs hcj
LEFT JOIN top_role_per_company tr 
  ON hcj.company_sk = tr.company_sk 
  AND tr.rn = 1
LEFT JOIN workspace.warehouse.dim_role r ON tr.role_sk = r.role_sk
GROUP BY hcj.company_sk, r.role_name

-- End of VIEW definition
