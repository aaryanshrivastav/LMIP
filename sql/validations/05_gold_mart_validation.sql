-- ============================================================================
-- Validation Script: Gold Mart Business Logic Validation
-- Purpose: Validate business rules and aggregation logic in Gold layer marts
-- Expected Output: List of validation failures with descriptions
-- Dependencies: All Gold layer views and their source warehouse tables
-- ============================================================================

-- Validation 1: gold_hiring_trends - Verify totals match source
WITH source_counts AS (
  SELECT
    posting_date_sk,
    sector_sk,
    COUNT(DISTINCT CASE WHEN is_new_job = TRUE THEN job_sk END) AS source_new_jobs,
    COUNT(DISTINCT CASE WHEN active_flag = TRUE THEN job_sk END) AS source_active_jobs
  FROM workspace.warehouse.fact_job_postings
  GROUP BY posting_date_sk, sector_sk
),
gold_counts AS (
  SELECT
    hiring_date_sk,
    sector_sk,
    total_new_jobs,
    total_active_jobs
  FROM workspace.gold.gold_hiring_trends
)
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_hiring_trends' AS table_name,
  'Mismatch between source and gold aggregation' AS validation_rule,
  CONCAT('Date SK: ', CAST(s.posting_date_sk AS STRING), ', Sector SK: ', CAST(s.sector_sk AS STRING)) AS key_value,
  CONCAT('Source: ', CAST(s.source_new_jobs AS STRING), ' new jobs, Gold: ', CAST(g.total_new_jobs AS STRING)) AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM source_counts s
FULL OUTER JOIN gold_counts g 
  ON s.posting_date_sk = g.hiring_date_sk 
  AND s.sector_sk = g.sector_sk
WHERE s.source_new_jobs != g.total_new_jobs
   OR s.source_active_jobs != g.total_active_jobs
   OR s.posting_date_sk IS NULL
   OR g.hiring_date_sk IS NULL

UNION ALL

-- Validation 2: gold_skill_demand - Verify skill counts match bridge table
WITH source_skill_counts AS (
  SELECT
    skill_sk,
    COUNT(DISTINCT job_sk) AS source_job_count
  FROM workspace.warehouse.bridge_job_skill
  GROUP BY skill_sk
),
gold_skill_counts AS (
  SELECT
    skill_sk,
    job_postings_count
  FROM workspace.gold.gold_skill_demand
)
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_skill_demand' AS table_name,
  'Skill job count mismatch' AS validation_rule,
  CONCAT('Skill SK: ', CAST(COALESCE(s.skill_sk, g.skill_sk) AS STRING)) AS key_value,
  CONCAT('Source: ', CAST(s.source_job_count AS STRING), ', Gold: ', CAST(g.job_postings_count AS STRING)) AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM source_skill_counts s
FULL OUTER JOIN gold_skill_counts g ON s.skill_sk = g.skill_sk
WHERE s.source_job_count != g.job_postings_count
   OR s.skill_sk IS NULL
   OR g.skill_sk IS NULL

UNION ALL

-- Validation 3: gold_salary_trends - Verify salary aggregations are reasonable
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_salary_trends' AS table_name,
  'Invalid salary range (min > max)' AS validation_rule,
  CONCAT('Role SK: ', CAST(role_sk AS STRING), ', Sector SK: ', CAST(sector_sk AS STRING)) AS key_value,
  CONCAT('Min: ', CAST(avg_salary_min AS STRING), ', Max: ', CAST(avg_salary_max AS STRING)) AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_salary_trends
WHERE avg_salary_min > avg_salary_max

UNION ALL

-- Validation 4: gold_location_trends - Verify no negative counts
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_location_trends' AS table_name,
  'Negative job count detected' AS validation_rule,
  'location_sk varies' AS key_value,
  'Negative counts are logically invalid' AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_location_trends
WHERE total_new_jobs < 0 
   OR total_active_jobs < 0 
   OR total_closed_jobs < 0
LIMIT 100

UNION ALL

-- Validation 5: gold_company_hiring - Verify company exists in dimension
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_company_hiring' AS table_name,
  'Company not found in dim_company' AS validation_rule,
  CONCAT('Company SK: ', CAST(g.company_sk AS STRING)) AS key_value,
  'Orphaned company in gold mart' AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_company_hiring g
LEFT JOIN workspace.warehouse.dim_company c ON g.company_sk = c.company_sk
WHERE c.company_sk IS NULL

UNION ALL

-- Validation 6: gold_sector_overview - Verify sector aggregations sum correctly
WITH sector_totals AS (
  SELECT
    SUM(total_jobs) AS sum_total_jobs,
    SUM(total_companies) AS sum_total_companies
  FROM workspace.gold.gold_sector_overview
),
fact_totals AS (
  SELECT
    COUNT(DISTINCT job_sk) AS fact_total_jobs,
    COUNT(DISTINCT company_sk) AS fact_total_companies
  FROM workspace.warehouse.fact_job_postings
  WHERE active_flag = TRUE
)
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_sector_overview' AS table_name,
  'Sector totals do not match fact table' AS validation_rule,
  'aggregate_comparison' AS key_value,
  CONCAT('Sector Sum Jobs: ', CAST(st.sum_total_jobs AS STRING), 
         ', Fact Total: ', CAST(ft.fact_total_jobs AS STRING)) AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM sector_totals st
CROSS JOIN fact_totals ft
WHERE st.sum_total_jobs != ft.fact_total_jobs
   OR st.sum_total_companies != ft.fact_total_companies

UNION ALL

-- Validation 7: gold_hiring_trends - Verify date range is reasonable
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_hiring_trends' AS table_name,
  'Future dates detected in hiring trends' AS validation_rule,
  CONCAT('Date SK: ', CAST(hiring_date_sk AS STRING)) AS key_value,
  'Dates should not be in the future' AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_hiring_trends
WHERE hiring_date_sk > INT(DATE_FORMAT(CURRENT_DATE(), 'yyyyMMdd'))

UNION ALL

-- Validation 8: gold_skill_demand - Verify avg_max_salary is reasonable
SELECT
  'GOLD_VALIDATION' AS validation_type,
  'gold_skill_demand' AS table_name,
  'Unrealistic average salary detected' AS validation_rule,
  CONCAT('Skill SK: ', CAST(skill_sk AS STRING)) AS key_value,
  CONCAT('Avg Max Salary: ', CAST(avg_max_salary AS STRING)) AS details,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_skill_demand
WHERE avg_max_salary < 0 OR avg_max_salary > 1000000

ORDER BY validation_type, table_name, validation_rule;