-- =====================================================
-- LMIP Data Quality Framework
-- Freshness Validation Rules
-- =====================================================
-- Purpose: Validate that data is being updated regularly
-- Severity: WARNING - Stale data may indicate pipeline issues
--           ERROR - Critical data missing updates
-- =====================================================

-- RULE: BR_FRESH_001 - Bronze Ingestion Freshness
-- Target: workspace.bronze.bronze_job_snapshot
-- Severity: WARNING
-- Action: ALERT
SELECT 
  'BR_FRESH_001' AS rule_name,
  'Freshness' AS rule_category,
  'WARNING' AS severity,
  COUNT(DISTINCT source_name) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'bronze' AS target_schema,
  'bronze_job_snapshot' AS target_table,
  CONCAT('Sources not ingested in last 24 hours: ', COLLECT_SET(source_name)) AS description
FROM (
  SELECT DISTINCT source_name
  FROM workspace.bronze.bronze_job_snapshot
  WHERE source_name NOT IN (
    SELECT DISTINCT source_name
    FROM workspace.bronze.bronze_job_snapshot
    WHERE ingestion_timestamp >= CURRENT_TIMESTAMP() - INTERVAL 24 HOURS
  )
)
HAVING COUNT(DISTINCT source_name) > 0;

-- RULE: SV_FRESH_001 - Silver Jobs Current Update Freshness
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: ALERT
SELECT 
  'SV_FRESH_001' AS rule_name,
  'Freshness' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  'Active jobs not updated in last 48 hours' AS description
FROM workspace.silver.silver_jobs_current
WHERE is_active = TRUE 
  AND updated_at < CURRENT_TIMESTAMP() - INTERVAL 48 HOURS
HAVING COUNT(*) > 0;

-- RULE: SV_FRESH_002 - Silver Jobs Last Seen Freshness
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: ALERT
SELECT 
  'SV_FRESH_002' AS rule_name,
  'Freshness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  'Active jobs not seen in last 7 days' AS description
FROM workspace.silver.silver_jobs_current
WHERE is_active = TRUE 
  AND last_seen < CURRENT_TIMESTAMP() - INTERVAL 7 DAYS
HAVING COUNT(*) > 0;

-- RULE: SM_FRESH_001 - Semantic Layer Update Freshness
-- Target: workspace.semantic.sem_sector_map
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SM_FRESH_001' AS rule_name,
  'Freshness' AS rule_category,
  'WARNING' AS severity,
  0 AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  CONCAT('Last semantic mapping: ', MAX(created_at)) AS description
FROM workspace.semantic.sem_sector_map
WHERE created_at < CURRENT_TIMESTAMP() - INTERVAL 7 DAYS;

-- RULE: WH_FRESH_001 - Warehouse Fact Table Freshness
-- Target: workspace.warehouse.fact_job_postings
-- Severity: WARNING
-- Action: ALERT
SELECT 
  'WH_FRESH_001' AS rule_name,
  'Freshness' AS rule_category,
  'WARNING' AS severity,
  0 AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_job_postings' AS target_table,
  CONCAT('Last warehouse load: ', MAX(load_timestamp)) AS description
FROM workspace.warehouse.fact_job_postings
WHERE load_timestamp < CURRENT_TIMESTAMP() - INTERVAL 24 HOURS;

-- RULE: GD_FRESH_001 - Gold Layer Aggregation Freshness
-- Target: workspace.gold.gold_hiring_trends
-- Severity: WARNING
-- Action: ALERT
SELECT 
  'GD_FRESH_001' AS rule_name,
  'Freshness' AS rule_category,
  'WARNING' AS severity,
  0 AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'gold' AS target_schema,
  'gold_hiring_trends' AS target_table,
  CONCAT('Last trend calculation: ', MAX(calculated_at)) AS description
FROM workspace.gold.gold_hiring_trends
WHERE calculated_at < CURRENT_TIMESTAMP() - INTERVAL 24 HOURS;

-- RULE: AUDIT_FRESH_001 - DQ Validation Execution Freshness
-- Target: workspace.audit.audit_dq_results
-- Severity: ERROR
-- Action: ALERT
SELECT 
  'AUDIT_FRESH_001' AS rule_name,
  'Freshness' AS rule_category,
  'ERROR' AS severity,
  0 AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'audit' AS target_schema,
  'audit_dq_results' AS target_table,
  CONCAT('Last DQ validation: ', MAX(evaluated_at)) AS description
FROM workspace.audit.audit_dq_results
WHERE evaluated_at < CURRENT_TIMESTAMP() - INTERVAL 24 HOURS;

-- =====================================================
-- END OF FRESHNESS VALIDATIONS
-- =====================================================
