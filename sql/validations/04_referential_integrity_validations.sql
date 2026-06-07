-- =====================================================
-- LMIP Data Quality Framework
-- Referential Integrity Validation Rules
-- =====================================================
-- Purpose: Validate foreign key relationships across tables
-- Severity: ERROR - Orphaned records indicate data corruption
-- =====================================================

-- RULE: SV_REF_001 - Silver Jobs to Bronze Source Integrity
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SV_REF_001' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current sj
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.bronze.bronze_job_snapshot bj
  WHERE bj.source_name = sj.source_name 
    AND bj.source_job_id = sj.source_job_id
)
AND sj.source_name IS NOT NULL 
AND sj.source_job_id IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: SM_REF_001 - Semantic Sector Map to Silver Jobs Integrity
-- Target: workspace.semantic.sem_sector_map
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_REF_001' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  COLLECT_LIST(sector_map_id) AS failed_ids
FROM workspace.semantic.sem_sector_map ssm
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.silver.silver_jobs_current sj
  WHERE sj.enterprise_job_id = ssm.enterprise_job_id
)
AND ssm.enterprise_job_id IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: SM_REF_002 - Semantic Company Map to Silver Jobs Integrity
-- Target: workspace.semantic.sem_company_map
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SM_REF_002' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_company_map' AS target_table,
  'Orphaned company mappings' AS description
FROM workspace.semantic.sem_company_map scm
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.silver.silver_jobs_current sj
  WHERE sj.enterprise_job_id = scm.enterprise_job_id
)
AND scm.enterprise_job_id IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: WH_REF_001 - Fact Job Postings to Dim Job Integrity
-- Target: workspace.warehouse.fact_job_postings
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_REF_001' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_job_postings' AS target_table,
  'Orphaned job_sk' AS description
FROM workspace.warehouse.fact_job_postings fjp
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.warehouse.dim_job dj
  WHERE dj.job_sk = fjp.job_sk
)
AND fjp.job_sk IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: WH_REF_002 - Fact Job Postings to Dim Company Integrity
-- Target: workspace.warehouse.fact_job_postings
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_REF_002' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_job_postings' AS target_table,
  'Orphaned company_sk' AS description
FROM workspace.warehouse.fact_job_postings fjp
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.warehouse.dim_company dc
  WHERE dc.company_sk = fjp.company_sk
)
AND fjp.company_sk IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: WH_REF_003 - Fact Job Postings to Dim Location Integrity
-- Target: workspace.warehouse.fact_job_postings
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_REF_003' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_job_postings' AS target_table,
  'Orphaned location_sk' AS description
FROM workspace.warehouse.fact_job_postings fjp
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.warehouse.dim_location dl
  WHERE dl.location_sk = fjp.location_sk
)
AND fjp.location_sk IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: WH_REF_004 - Fact Job Postings to Dim Sector Integrity
-- Target: workspace.warehouse.fact_job_postings
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_REF_004' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_job_postings' AS target_table,
  'Orphaned sector_sk' AS description
FROM workspace.warehouse.fact_job_postings fjp
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.warehouse.dim_sector ds
  WHERE ds.sector_sk = fjp.sector_sk
)
AND fjp.sector_sk IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: WH_REF_005 - Fact Salary to Dim Tables Integrity
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_REF_005' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  'Orphaned foreign keys in fact_salary' AS description
FROM workspace.warehouse.fact_salary fs
WHERE (fs.job_sk IS NOT NULL AND NOT EXISTS (SELECT 1 FROM workspace.warehouse.dim_job WHERE job_sk = fs.job_sk))
   OR (fs.company_sk IS NOT NULL AND NOT EXISTS (SELECT 1 FROM workspace.warehouse.dim_company WHERE company_sk = fs.company_sk))
   OR (fs.location_sk IS NOT NULL AND NOT EXISTS (SELECT 1 FROM workspace.warehouse.dim_location WHERE location_sk = fs.location_sk))
   OR (fs.sector_sk IS NOT NULL AND NOT EXISTS (SELECT 1 FROM workspace.warehouse.dim_sector WHERE sector_sk = fs.sector_sk))
HAVING COUNT(*) > 0;

-- RULE: WH_REF_006 - Bridge Job Skill Integrity
-- Target: workspace.warehouse.bridge_job_skill
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'WH_REF_006' AS rule_name,
  'Referential Integrity' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'bridge_job_skill' AS target_table,
  'Orphaned job_sk or skill_sk in bridge table' AS description
FROM workspace.warehouse.bridge_job_skill bjs
WHERE (bjs.job_sk IS NOT NULL AND NOT EXISTS (SELECT 1 FROM workspace.warehouse.dim_job WHERE job_sk = bjs.job_sk))
   OR (bjs.skill_sk IS NOT NULL AND NOT EXISTS (SELECT 1 FROM workspace.warehouse.dim_skill WHERE skill_sk = bjs.skill_sk))
HAVING COUNT(*) > 0;

-- RULE: QUAR_REF_001 - Quarantine to Silver Jobs Integrity
-- Target: workspace.quarantine.quarantine_jobs
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'QUAR_REF_001' AS rule_name,
  'Referential Integrity' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'quarantine' AS target_schema,
  'quarantine_jobs' AS target_table,
  'Quarantined records referencing non-existent enterprise_job_id' AS description
FROM workspace.quarantine.quarantine_jobs qj
WHERE qj.enterprise_job_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 
    FROM workspace.silver.silver_jobs_current sj
    WHERE sj.enterprise_job_id = qj.enterprise_job_id
  )
HAVING COUNT(*) > 0;

-- =====================================================
-- END OF REFERENTIAL INTEGRITY VALIDATIONS
-- =====================================================
