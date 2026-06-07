-- ============================================================================
-- Validation Script: Duplicate Detection
-- Purpose: Detect duplicate records based on primary keys and business keys
-- Expected Output: List of tables with duplicate counts
-- Dependencies: All tables with primary key or unique constraints
-- ============================================================================

-- Bronze Layer Duplicate Checks

-- bronze_job_snapshot - Check primary key duplicates
SELECT
  'BRONZE' AS layer,
  'bronze_job_snapshot' AS table_name,
  'snapshot_id' AS key_columns,
  snapshot_id AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_job_snapshot
GROUP BY snapshot_id
HAVING COUNT(*) > 1

UNION ALL

-- bronze_job_snapshot - Check business key duplicates
SELECT
  'BRONZE' AS layer,
  'bronze_job_snapshot' AS table_name,
  'job_id|batch_id|run_id' AS key_columns,
  CONCAT(job_id, '|', batch_id, '|', COALESCE(run_id, 'NULL')) AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_job_snapshot
GROUP BY job_id, batch_id, run_id
HAVING COUNT(*) > 1

UNION ALL

-- bronze_api_response_log - Check primary key duplicates
SELECT
  'BRONZE' AS layer,
  'bronze_api_response_log' AS table_name,
  'response_log_id' AS key_columns,
  response_log_id AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.bronze.bronze_api_response_log
GROUP BY response_log_id
HAVING COUNT(*) > 1

UNION ALL

-- Silver Layer Duplicate Checks

-- silver_jobs_current - Check primary key duplicates
SELECT
  'SILVER' AS layer,
  'silver_jobs_current' AS table_name,
  'enterprise_job_id' AS key_columns,
  enterprise_job_id AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_current
GROUP BY enterprise_job_id
HAVING COUNT(*) > 1

UNION ALL

-- silver_jobs_current - Check business key duplicates
SELECT
  'SILVER' AS layer,
  'silver_jobs_current' AS table_name,
  'source_name|source_job_id' AS key_columns,
  CONCAT(source_name, '|', source_job_id) AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_current
GROUP BY source_name, source_job_id
HAVING COUNT(*) > 1

UNION ALL

-- silver_job_changes - Check primary key duplicates
SELECT
  'SILVER' AS layer,
  'silver_job_changes' AS table_name,
  'change_id' AS key_columns,
  change_id AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_job_changes
GROUP BY change_id
HAVING COUNT(*) > 1

UNION ALL

-- Semantic Layer Duplicate Checks

-- sem_company_canonical - Check primary key duplicates
SELECT
  'SEMANTIC' AS layer,
  'sem_company_canonical' AS table_name,
  'company_name_norm' AS key_columns,
  company_name_norm AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.semantic.sem_company_canonical
GROUP BY company_name_norm
HAVING COUNT(*) > 1

UNION ALL

-- Warehouse Dimension Duplicate Checks

-- dim_date - Check primary key duplicates
SELECT
  'WAREHOUSE' AS layer,
  'dim_date' AS table_name,
  'date_sk' AS key_columns,
  CAST(date_sk AS STRING) AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_date
GROUP BY date_sk
HAVING COUNT(*) > 1

UNION ALL

-- dim_date - Check business key duplicates
SELECT
  'WAREHOUSE' AS layer,
  'dim_date' AS table_name,
  'date_value' AS key_columns,
  CAST(date_value AS STRING) AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_date
GROUP BY date_value
HAVING COUNT(*) > 1

UNION ALL

-- dim_job - Check primary key duplicates
SELECT
  'WAREHOUSE' AS layer,
  'dim_job' AS table_name,
  'job_sk' AS key_columns,
  CAST(job_sk AS STRING) AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job
GROUP BY job_sk
HAVING COUNT(*) > 1

UNION ALL

-- dim_job - Check SCD2 integrity (only one current record per enterprise_job_id)
SELECT
  'WAREHOUSE' AS layer,
  'dim_job' AS table_name,
  'enterprise_job_id (is_current=TRUE)' AS key_columns,
  enterprise_job_id AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job
WHERE is_current = TRUE
GROUP BY enterprise_job_id
HAVING COUNT(*) > 1

UNION ALL

-- Warehouse Fact Duplicate Checks

-- fact_job_postings - Check primary key duplicates
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS table_name,
  'fact_job_posting_sk' AS key_columns,
  CAST(fact_job_posting_sk AS STRING) AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings
GROUP BY fact_job_posting_sk
HAVING COUNT(*) > 1

UNION ALL

-- Gold Layer Duplicate Checks

-- gold_hiring_trends - Check composite primary key duplicates
SELECT
  'GOLD' AS layer,
  'gold_hiring_trends' AS table_name,
  'hiring_date_sk|sector_sk' AS key_columns,
  CONCAT(CAST(hiring_date_sk AS STRING), '|', CAST(sector_sk AS STRING)) AS key_value,
  COUNT(*) AS duplicate_count,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.gold.gold_hiring_trends
GROUP BY hiring_date_sk, sector_sk
HAVING COUNT(*) > 1

ORDER BY layer, table_name, key_columns;