-- =====================================================
-- LMIP Data Quality Framework
-- Business Logic Validation Rules
-- =====================================================
-- Purpose: Validate business rules and data logic
-- Severity: Varies based on business impact
-- =====================================================

-- RULE: BIZ_001 - Posted Date Not in Future
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BIZ_001' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE posted_at > CURRENT_TIMESTAMP()
HAVING COUNT(*) > 0;

-- RULE: BIZ_002 - Active Flag Consistency
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: AUTO_FIX
SELECT 
  'BIZ_002' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE soft_delete_flag = TRUE AND is_active = TRUE
HAVING COUNT(*) > 0;

-- RULE: BIZ_003 - Posted Date Before Last Seen
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BIZ_003' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE posted_at > last_seen
HAVING COUNT(*) > 0;

-- RULE: BIZ_004 - Created Before Updated
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BIZ_004' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE created_at > updated_at
HAVING COUNT(*) > 0;

-- RULE: BIZ_005 - Confidence Scores in Valid Range
-- Target: workspace.semantic.sem_sector_map
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BIZ_005' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  COLLECT_LIST(sector_map_id) AS failed_ids
FROM workspace.semantic.sem_sector_map
WHERE normalization_confidence < 0 OR normalization_confidence > 1
HAVING COUNT(*) > 0;

-- RULE: BIZ_006 - Remote Type Valid Values
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: FLAG_FOR_REVIEW
SELECT 
  'BIZ_006' AS rule_name,
  'Business Logic' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_SET(remote_type) AS invalid_values
FROM workspace.silver.silver_jobs_current
WHERE remote_type NOT IN ('REMOTE', 'HYBRID', 'ON_SITE', 'NOT_SPECIFIED') 
  AND remote_type IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: BIZ_007 - DQ Status Valid Values
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'BIZ_007' AS rule_name,
  'Business Logic' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_SET(dq_overall_status) AS invalid_values
FROM workspace.silver.silver_jobs_current
WHERE dq_overall_status NOT IN ('PASS', 'FAIL', 'WARNING', 'NOT_VALIDATED', 'IN_PROGRESS') 
  AND dq_overall_status IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: BIZ_008 - Salary Observation Type Valid Values
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'BIZ_008' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_SET(salary_observation_type) AS invalid_values
FROM workspace.warehouse.fact_salary
WHERE salary_observation_type NOT IN ('POSTED', 'INFERRED', 'REPORTED')
HAVING COUNT(*) > 0;

-- RULE: BIZ_009 - Dimension Active Flag Consistency
-- Target: workspace.warehouse.dim_sector
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'BIZ_009' AS rule_name,
  'Business Logic' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_sector' AS target_table,
  'Inactive sectors still referenced in fact tables' AS description
FROM workspace.warehouse.dim_sector ds
WHERE ds.active_flag = FALSE
  AND EXISTS (
    SELECT 1 
    FROM workspace.warehouse.fact_job_postings fjp
    WHERE fjp.sector_sk = ds.sector_sk
  )
HAVING COUNT(*) > 0;

-- RULE: BIZ_010 - Quarantine Severity Valid Values
-- Target: workspace.quarantine.quarantine_jobs
-- Severity: ERROR
-- Action: ALERT
SELECT 
  'BIZ_010' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'quarantine' AS target_schema,
  'quarantine_jobs' AS target_table,
  COLLECT_SET(severity) AS invalid_values
FROM workspace.quarantine.quarantine_jobs
WHERE severity NOT IN ('ERROR', 'WARNING')
HAVING COUNT(*) > 0;

-- RULE: BIZ_011 - Reprocess Status Valid Values
-- Target: workspace.quarantine.quarantine_jobs
-- Severity: ERROR
-- Action: ALERT
SELECT 
  'BIZ_011' AS rule_name,
  'Business Logic' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'quarantine' AS target_schema,
  'quarantine_jobs' AS target_table,
  COLLECT_SET(reprocess_status) AS invalid_values
FROM workspace.quarantine.quarantine_jobs
WHERE reprocess_status NOT IN ('PENDING', 'IN_PROGRESS', 'RESOLVED', 'DISCARDED')
HAVING COUNT(*) > 0;

-- =====================================================
-- END OF BUSINESS VALIDATIONS
-- =====================================================
