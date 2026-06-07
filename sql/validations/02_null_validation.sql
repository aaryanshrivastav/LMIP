-- ============================================================================
-- Validation Script: Null Value Validation
-- Purpose: Validate NOT NULL constraints across all critical columns
-- Expected Output: List of tables with null violations and counts
-- Dependencies: All tables in bronze, silver, semantic, warehouse, and gold layers
-- ============================================================================

-- Bronze Layer Null Checks
SELECT
  'BRONZE' AS layer,
  'bronze_job_snapshot' AS table_name,
  'snapshot_id' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_job_snapshot
WHERE snapshot_id IS NULL

UNION ALL

SELECT
  'BRONZE' AS layer,
  'bronze_job_snapshot' AS table_name,
  'job_id' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_job_snapshot
WHERE job_id IS NULL

UNION ALL

SELECT
  'BRONZE' AS layer,
  'bronze_job_snapshot' AS table_name,
  'batch_id' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_job_snapshot
WHERE batch_id IS NULL

UNION ALL

SELECT
  'BRONZE' AS layer,
  'bronze_job_snapshot' AS table_name,
  'status' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_job_snapshot
WHERE status IS NULL

UNION ALL

-- Silver Layer Null Checks
SELECT
  'SILVER' AS layer,
  'silver_jobs_current' AS table_name,
  'enterprise_job_id' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_current
WHERE enterprise_job_id IS NULL

UNION ALL

SELECT
  'SILVER' AS layer,
  'silver_jobs_current' AS table_name,
  'source_name' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_current
WHERE source_name IS NULL

UNION ALL

SELECT
  'SILVER' AS layer,
  'silver_jobs_current' AS table_name,
  'source_job_id' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_current
WHERE source_job_id IS NULL

UNION ALL

-- Semantic Layer Null Checks
SELECT
  'SEMANTIC' AS layer,
  'sem_company_canonical' AS table_name,
  'company_name_norm' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.semantic.sem_company_canonical
WHERE company_name_norm IS NULL

UNION ALL

SELECT
  'SEMANTIC' AS layer,
  'sem_company_canonical' AS table_name,
  'canonical_company_name' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.semantic.sem_company_canonical
WHERE canonical_company_name IS NULL

UNION ALL

-- Warehouse Dimension Null Checks
SELECT
  'WAREHOUSE' AS layer,
  'dim_job' AS table_name,
  'job_sk' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job
WHERE job_sk IS NULL

UNION ALL

SELECT
  'WAREHOUSE' AS layer,
  'dim_job' AS table_name,
  'enterprise_job_id' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job
WHERE enterprise_job_id IS NULL

UNION ALL

SELECT
  'WAREHOUSE' AS layer,
  'dim_job' AS table_name,
  'effective_from' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job
WHERE effective_from IS NULL

UNION ALL

SELECT
  'WAREHOUSE' AS layer,
  'dim_job' AS table_name,
  'is_current' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job
WHERE is_current IS NULL

UNION ALL

-- Warehouse Fact Null Checks
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS table_name,
  'fact_job_posting_sk' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings
WHERE fact_job_posting_sk IS NULL

UNION ALL

SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS table_name,
  'job_sk' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings
WHERE job_sk IS NULL

UNION ALL

SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS table_name,
  'posting_timestamp' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings
WHERE posting_timestamp IS NULL

UNION ALL

-- Gold Layer Null Checks
SELECT
  'GOLD' AS layer,
  'gold_hiring_trends' AS table_name,
  'hiring_date_sk' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_hiring_trends
WHERE hiring_date_sk IS NULL

UNION ALL

SELECT
  'GOLD' AS layer,
  'gold_hiring_trends' AS table_name,
  'sector_sk' AS column_name,
  COUNT(*) AS null_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_hiring_trends
WHERE sector_sk IS NULL

ORDER BY layer, table_name, column_name;