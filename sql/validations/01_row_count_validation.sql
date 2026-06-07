-- ============================================================================
-- Validation Script: Row Count Validation
-- Purpose: Validate row counts across all LMIP tables
-- Expected Output: Table with row counts, timestamps, and alerts for empty tables
-- Dependencies: All tables in bronze, silver, semantic, warehouse, and gold layers
-- ============================================================================

-- Bronze Layer Row Counts
SELECT 
  'BRONZE' AS layer,
  'bronze_job_snapshot' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_job_snapshot

UNION ALL

SELECT 
  'BRONZE' AS layer,
  'bronze_api_response_log' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_api_response_log

UNION ALL

SELECT 
  'BRONZE' AS layer,
  'dedupe_tracking' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.dedupe_tracking

UNION ALL

-- Silver Layer Row Counts
SELECT 
  'SILVER' AS layer,
  'silver_jobs_staging' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_staging

UNION ALL

SELECT 
  'SILVER' AS layer,
  'silver_jobs_current' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_current

UNION ALL

SELECT 
  'SILVER' AS layer,
  'silver_job_changes' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_job_changes

UNION ALL

SELECT 
  'SILVER' AS layer,
  'silver_job_identity_map' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_job_identity_map

UNION ALL

SELECT 
  'SILVER' AS layer,
  'silver_skill_mapping' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_skill_mapping

UNION ALL

-- Semantic Layer Row Counts
SELECT 
  'SEMANTIC' AS layer,
  'sem_company_canonical' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.semantic.sem_company_canonical

UNION ALL

SELECT 
  'SEMANTIC' AS layer,
  'sem_skill_catalog' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.semantic.sem_skill_catalog

UNION ALL

-- Warehouse Dimension Row Counts
SELECT 
  'WAREHOUSE' AS layer,
  'dim_date' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_date

UNION ALL

SELECT 
  'WAREHOUSE' AS layer,
  'dim_company' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_company

UNION ALL

SELECT 
  'WAREHOUSE' AS layer,
  'dim_job' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job

UNION ALL

SELECT 
  'WAREHOUSE' AS layer,
  'dim_skill' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_skill

UNION ALL

-- Warehouse Fact Row Counts
SELECT 
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings

UNION ALL

SELECT 
  'WAREHOUSE' AS layer,
  'fact_salary' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_salary

UNION ALL

SELECT 
  'WAREHOUSE' AS layer,
  'bridge_job_skill' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.bridge_job_skill

UNION ALL

-- Gold Layer Row Counts
SELECT 
  'GOLD' AS layer,
  'gold_hiring_trends' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_hiring_trends

UNION ALL

SELECT 
  'GOLD' AS layer,
  'gold_skill_demand' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_skill_demand

UNION ALL

SELECT 
  'GOLD' AS layer,
  'gold_salary_trends' AS table_name,
  COUNT(*) AS row_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_salary_trends

ORDER BY layer, table_name;