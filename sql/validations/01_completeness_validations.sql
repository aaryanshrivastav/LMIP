-- =====================================================
-- LMIP Data Quality Framework
-- Completeness Validation Rules
-- =====================================================
-- Purpose: Validate that critical fields are populated across all data layers
-- Severity: ERROR - Records with missing critical fields should be quarantined
--           WARNING - Records with missing optional but important fields
-- =====================================================

-- =====================================================
-- BRONZE LAYER COMPLETENESS RULES
-- =====================================================

-- RULE: BR_COMPL_001 - Bronze Job Snapshot Required Fields
-- Target: workspace.bronze.bronze_job_snapshot
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BR_COMPL_001' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'bronze' AS target_schema,
  'bronze_job_snapshot' AS target_table,
  COLLECT_LIST(snapshot_id) AS failed_ids
FROM workspace.bronze.bronze_job_snapshot
WHERE snapshot_id IS NULL 
   OR source_name IS NULL 
   OR source_job_id IS NULL 
   OR payload_json IS NULL 
   OR ingestion_timestamp IS NULL
HAVING COUNT(*) > 0;

-- RULE: BR_COMPL_002 - Batch Metadata Completeness
-- Target: workspace.bronze.batch_metadata
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BR_COMPL_002' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'bronze' AS target_schema,
  'batch_metadata' AS target_table,
  'batch_id, source_name, started_at must not be null' AS description
FROM workspace.bronze.batch_metadata
WHERE batch_id IS NULL 
   OR source_name IS NULL 
   OR started_at IS NULL
HAVING COUNT(*) > 0;

-- =====================================================
-- SILVER LAYER COMPLETENESS RULES
-- =====================================================

-- RULE: SV_COMPL_001 - Silver Jobs Current Critical Fields
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SV_COMPL_001' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE enterprise_job_id IS NULL 
   OR source_name IS NULL 
   OR source_job_id IS NULL 
   OR title_raw IS NULL 
   OR posted_at IS NULL 
   OR is_active IS NULL
HAVING COUNT(*) > 0;

-- RULE: SV_COMPL_002 - Silver Jobs Normalized Fields
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: FLAG_FOR_REVIEW
SELECT 
  'SV_COMPL_002' AS rule_name,
  'Completeness' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE is_active = TRUE 
  AND (company_name_norm IS NULL 
       OR title_normalized IS NULL 
       OR location_norm IS NULL)
HAVING COUNT(*) > 0;

-- RULE: SV_COMPL_003 - Silver Skill Mapping Completeness
-- Target: workspace.silver.silver_skill_mapping
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SV_COMPL_003' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_skill_mapping' AS target_table,
  'enterprise_job_id and skill_name_raw must not be null' AS description
FROM workspace.silver.silver_skill_mapping
WHERE enterprise_job_id IS NULL 
   OR skill_name_raw IS NULL
HAVING COUNT(*) > 0;

-- =====================================================
-- SEMANTIC LAYER COMPLETENESS RULES
-- =====================================================

-- RULE: SM_COMPL_001 - Semantic Sector Map Completeness
-- Target: workspace.semantic.sem_sector_map
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_COMPL_001' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  COLLECT_LIST(sector_map_id) AS failed_ids
FROM workspace.semantic.sem_sector_map
WHERE sector_map_id IS NULL 
   OR enterprise_job_id IS NULL 
   OR canonical_sector_code IS NULL 
   OR canonical_sector_name IS NULL
HAVING COUNT(*) > 0;

-- RULE: SM_COMPL_002 - Semantic Company Canonical Completeness
-- Target: workspace.semantic.sem_company_canonical
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_COMPL_002' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_company_canonical' AS target_table,
  'canonical_company_id and canonical_company_name must not be null' AS description
FROM workspace.semantic.sem_company_canonical
WHERE canonical_company_id IS NULL 
   OR canonical_company_name IS NULL
HAVING COUNT(*) > 0;

-- RULE: SM_COMPL_003 - Semantic Skill Catalog Completeness
-- Target: workspace.semantic.sem_skill_catalog
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_COMPL_003' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_skill_catalog' AS target_table,
  'canonical_skill_id and canonical_skill_name must not be null' AS description
FROM workspace.semantic.sem_skill_catalog
WHERE canonical_skill_id IS NULL 
   OR canonical_skill_name IS NULL
HAVING COUNT(*) > 0;

-- =====================================================
-- WAREHOUSE LAYER COMPLETENESS RULES
-- =====================================================

-- RULE: WH_COMPL_001 - Dim Company Required Fields
-- Target: workspace.warehouse.dim_company
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_COMPL_001' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_company' AS target_table,
  'company_sk and company_name must not be null' AS description
FROM workspace.warehouse.dim_company
WHERE company_sk IS NULL 
   OR company_name IS NULL
HAVING COUNT(*) > 0;

-- RULE: WH_COMPL_002 - Dim Location Required Fields
-- Target: workspace.warehouse.dim_location
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_COMPL_002' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  COLLECT_LIST(location_sk) AS failed_ids
FROM workspace.warehouse.dim_location
WHERE location_sk IS NULL 
   OR location_name IS NULL 
   OR active_flag IS NULL
HAVING COUNT(*) > 0;

-- RULE: WH_COMPL_003 - Dim Sector Required Fields
-- Target: workspace.warehouse.dim_sector
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_COMPL_003' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_sector' AS target_table,
  COLLECT_LIST(sector_sk) AS failed_ids
FROM workspace.warehouse.dim_sector
WHERE sector_sk IS NULL 
   OR sector_name IS NULL 
   OR sector_family IS NULL 
   OR active_flag IS NULL
HAVING COUNT(*) > 0;

-- RULE: WH_COMPL_004 - Fact Job Postings Foreign Keys
-- Target: workspace.warehouse.fact_job_postings
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_COMPL_004' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_job_postings' AS target_table,
  'All foreign keys must not be null' AS description
FROM workspace.warehouse.fact_job_postings
WHERE job_sk IS NULL 
   OR company_sk IS NULL 
   OR location_sk IS NULL 
   OR sector_sk IS NULL 
   OR source_sk IS NULL
HAVING COUNT(*) > 0;

-- RULE: WH_COMPL_005 - Fact Salary Required Fields
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_COMPL_005' AS rule_name,
  'Completeness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_LIST(fact_salary_sk) AS failed_ids
FROM workspace.warehouse.fact_salary
WHERE fact_salary_sk IS NULL 
   OR job_sk IS NULL 
   OR observation_date_sk IS NULL 
   OR salary_observation_type IS NULL
HAVING COUNT(*) > 0;

-- =====================================================
-- GOLD LAYER COMPLETENESS RULES
-- =====================================================

-- RULE: GD_COMPL_001 - Gold Hiring Trends Completeness
-- Target: workspace.gold.gold_hiring_trends
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'GD_COMPL_001' AS rule_name,
  'Completeness' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'gold' AS target_schema,
  'gold_hiring_trends' AS target_table,
  'Critical trend metrics should not be null' AS description
FROM workspace.gold.gold_hiring_trends
WHERE trend_period IS NULL 
   OR total_postings IS NULL
HAVING COUNT(*) > 0;

-- RULE: GD_COMPL_002 - Gold Salary Trends Completeness
-- Target: workspace.gold.gold_salary_trends
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'GD_COMPL_002' AS rule_name,
  'Completeness' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'gold' AS target_schema,
  'gold_salary_trends' AS target_table,
  'Salary metrics should not be null' AS description
FROM workspace.gold.gold_salary_trends
WHERE observation_period IS NULL 
   OR median_salary IS NULL
HAVING COUNT(*) > 0;

-- =====================================================
-- END OF COMPLETENESS VALIDATIONS
-- =====================================================
