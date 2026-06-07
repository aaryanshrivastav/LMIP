-- ============================================================================
-- View: workspace.gold.gold_salary_trends
-- Layer: GOLD
-- Description: Salary trends by role, sector, and location
-- ============================================================================
-- Purpose: Compensation analysis across different dimensions
-- Dependencies: workspace.warehouse.fact_salary, workspace.warehouse.dim_role, workspace.warehouse.dim_sector
-- Expected Output: Aggregated salary statistics by role/sector/location
-- ============================================================================

CREATE OR REPLACE VIEW workspace.gold.gold_salary_trends AS
SELECT
  r.role_sk,
  r.role_name,
  s.sector_sk,
  s.sector_name,
  COUNT(*) AS sample_size,
  AVG(fs.salary_min) AS avg_salary_min,
  AVG(fs.salary_max) AS avg_salary_max,
  PERCENTILE(fs.salary_max, 0.5) AS median_salary_max,
  PERCENTILE(fs.salary_max, 0.25) AS p25_salary,
  PERCENTILE(fs.salary_max, 0.75) AS p75_salary,
  CURRENT_TIMESTAMP() AS updated_at
FROM workspace.warehouse.fact_salary fs
JOIN workspace.warehouse.dim_role r ON fs.role_sk = r.role_sk
JOIN workspace.warehouse.dim_sector s ON fs.sector_sk = s.sector_sk
WHERE fs.is_current = TRUE
GROUP BY r.role_sk, r.role_name, s.sector_sk, s.sector_name;

-- End of VIEW definition
