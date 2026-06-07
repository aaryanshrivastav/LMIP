-- =====================================================
-- LMIP Data Quality Framework
-- Uniqueness Validation Rules
-- =====================================================
-- Purpose: Validate that primary and natural keys are unique
-- Severity: ERROR - Duplicate keys indicate data corruption
-- =====================================================

-- =====================================================
-- BRONZE LAYER UNIQUENESS RULES
-- =====================================================

-- RULE: BR_UNIQ_001 - Bronze Job Snapshot Duplicate Check
-- Target: workspace.bronze.bronze_job_snapshot
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BR_UNIQ_001' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'bronze' AS target_schema,
  'bronze_job_snapshot' AS target_table,
  'Duplicate snapshot_id detected' AS description
FROM (
  SELECT snapshot_id, COUNT(*) as cnt
  FROM workspace.bronze.bronze_job_snapshot
  WHERE snapshot_id IS NOT NULL
  GROUP BY snapshot_id
  HAVING COUNT(*) > 1
);

-- RULE: BR_UNIQ_002 - Bronze Job Snapshot Payload Hash Check
-- Target: workspace.bronze.bronze_job_snapshot
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'BR_UNIQ_002' AS rule_name,
  'Uniqueness' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'bronze' AS target_schema,
  'bronze_job_snapshot' AS target_table,
  'Duplicate payload_hash within same batch' AS description
FROM (
  SELECT batch_id, payload_hash, COUNT(*) as cnt
  FROM workspace.bronze.bronze_job_snapshot
  WHERE payload_hash IS NOT NULL
  GROUP BY batch_id, payload_hash
  HAVING COUNT(*) > 1
);

-- =====================================================
-- SILVER LAYER UNIQUENESS RULES
-- =====================================================

-- RULE: SV_UNIQ_001 - Silver Jobs Current Duplicate enterprise_job_id
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SV_UNIQ_001' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  'Duplicate enterprise_job_id' AS description
FROM (
  SELECT enterprise_job_id, COUNT(*) as cnt
  FROM workspace.silver.silver_jobs_current
  WHERE enterprise_job_id IS NOT NULL
  GROUP BY enterprise_job_id
  HAVING COUNT(*) > 1
);

-- RULE: SV_UNIQ_002 - Silver Jobs Current Duplicate source job
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SV_UNIQ_002' AS rule_name,
  'Uniqueness' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  'Duplicate source_name + source_job_id combination' AS description
FROM (
  SELECT source_name, source_job_id, COUNT(*) as cnt
  FROM workspace.silver.silver_jobs_current
  WHERE source_name IS NOT NULL AND source_job_id IS NOT NULL
  GROUP BY source_name, source_job_id
  HAVING COUNT(*) > 1
);

-- RULE: SV_UNIQ_003 - Silver Job Identity Map Uniqueness
-- Target: workspace.silver.silver_job_identity_map
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SV_UNIQ_003' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_job_identity_map' AS target_table,
  'Duplicate mapping_id' AS description
FROM (
  SELECT mapping_id, COUNT(*) as cnt
  FROM workspace.silver.silver_job_identity_map
  WHERE mapping_id IS NOT NULL
  GROUP BY mapping_id
  HAVING COUNT(*) > 1
);

-- =====================================================
-- SEMANTIC LAYER UNIQUENESS RULES
-- =====================================================

-- RULE: SM_UNIQ_001 - Semantic Company Canonical Duplicate Check
-- Target: workspace.semantic.sem_company_canonical
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_UNIQ_001' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_company_canonical' AS target_table,
  'Duplicate canonical_company_id' AS description
FROM (
  SELECT canonical_company_id, COUNT(*) as cnt
  FROM workspace.semantic.sem_company_canonical
  WHERE canonical_company_id IS NOT NULL
  GROUP BY canonical_company_id
  HAVING COUNT(*) > 1
);

-- RULE: SM_UNIQ_002 - Semantic Skill Catalog Duplicate Check
-- Target: workspace.semantic.sem_skill_catalog
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_UNIQ_002' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_skill_catalog' AS target_table,
  'Duplicate canonical_skill_id' AS description
FROM (
  SELECT canonical_skill_id, COUNT(*) as cnt
  FROM workspace.semantic.sem_skill_catalog
  WHERE canonical_skill_id IS NOT NULL
  GROUP BY canonical_skill_id
  HAVING COUNT(*) > 1
);

-- RULE: SM_UNIQ_003 - Semantic Sector Map Duplicate Check
-- Target: workspace.semantic.sem_sector_map
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_UNIQ_003' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  'Duplicate sector_map_id' AS description
FROM (
  SELECT sector_map_id, COUNT(*) as cnt
  FROM workspace.semantic.sem_sector_map
  WHERE sector_map_id IS NOT NULL
  GROUP BY sector_map_id
  HAVING COUNT(*) > 1
);

-- =====================================================
-- WAREHOUSE LAYER UNIQUENESS RULES
-- =====================================================

-- RULE: WH_UNIQ_001 - Dim Company SK Uniqueness
-- Target: workspace.warehouse.dim_company
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_UNIQ_001' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_company' AS target_table,
  'Duplicate company_sk' AS description
FROM (
  SELECT company_sk, COUNT(*) as cnt
  FROM workspace.warehouse.dim_company
  WHERE company_sk IS NOT NULL
  GROUP BY company_sk
  HAVING COUNT(*) > 1
);

-- RULE: WH_UNIQ_002 - Dim Location SK Uniqueness
-- Target: workspace.warehouse.dim_location
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_UNIQ_002' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  'Duplicate location_sk' AS description
FROM (
  SELECT location_sk, COUNT(*) as cnt
  FROM workspace.warehouse.dim_location
  WHERE location_sk IS NOT NULL
  GROUP BY location_sk
  HAVING COUNT(*) > 1
);

-- RULE: WH_UNIQ_003 - Dim Sector SK Uniqueness
-- Target: workspace.warehouse.dim_sector
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_UNIQ_003' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_sector' AS target_table,
  'Duplicate sector_sk' AS description
FROM (
  SELECT sector_sk, COUNT(*) as cnt
  FROM workspace.warehouse.dim_sector
  WHERE sector_sk IS NOT NULL
  GROUP BY sector_sk
  HAVING COUNT(*) > 1
);

-- RULE: WH_UNIQ_004 - Dim Skill SK Uniqueness
-- Target: workspace.warehouse.dim_skill
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_UNIQ_004' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_skill' AS target_table,
  'Duplicate skill_sk' AS description
FROM (
  SELECT skill_sk, COUNT(*) as cnt
  FROM workspace.warehouse.dim_skill
  WHERE skill_sk IS NOT NULL
  GROUP BY skill_sk
  HAVING COUNT(*) > 1
);

-- RULE: WH_UNIQ_005 - Fact Salary SK Uniqueness
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_UNIQ_005' AS rule_name,
  'Uniqueness' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  'Duplicate fact_salary_sk' AS description
FROM (
  SELECT fact_salary_sk, COUNT(*) as cnt
  FROM workspace.warehouse.fact_salary
  WHERE fact_salary_sk IS NOT NULL
  GROUP BY fact_salary_sk
  HAVING COUNT(*) > 1
);

-- =====================================================
-- GOLD LAYER UNIQUENESS RULES
-- =====================================================

-- RULE: GD_UNIQ_001 - Canonical Companies Mappings Duplicate Check
-- Target: workspace.gold.canonical_companies_mappings
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'GD_UNIQ_001' AS rule_name,
  'Uniqueness' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'gold' AS target_schema,
  'canonical_companies_mappings' AS target_table,
  'Duplicate mapping entries' AS description
FROM (
  SELECT canonical_company_id, raw_company_name, COUNT(*) as cnt
  FROM workspace.gold.canonical_companies_mappings
  WHERE canonical_company_id IS NOT NULL AND raw_company_name IS NOT NULL
  GROUP BY canonical_company_id, raw_company_name
  HAVING COUNT(*) > 1
);

-- =====================================================
-- END OF UNIQUENESS VALIDATIONS
-- =====================================================
