-- =====================================================
-- LMIP Data Quality Framework
-- Salary Validation Rules
-- =====================================================
-- Purpose: Validate salary data quality and business rules
-- Severity: ERROR for invalid ranges, WARNING for outliers
-- =====================================================

-- RULE: SAL_001 - Salary Min Less Than Max
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SAL_001' AS rule_name,
  'Salary Validation' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_LIST(fact_salary_sk) AS failed_ids
FROM workspace.warehouse.fact_salary
WHERE salary_min IS NOT NULL 
  AND salary_max IS NOT NULL 
  AND salary_min > salary_max
HAVING COUNT(*) > 0;

-- RULE: SAL_002 - Salary Values Positive
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SAL_002' AS rule_name,
  'Salary Validation' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_LIST(fact_salary_sk) AS failed_ids
FROM workspace.warehouse.fact_salary
WHERE (salary_min IS NOT NULL AND salary_min <= 0)
   OR (salary_max IS NOT NULL AND salary_max <= 0)
HAVING COUNT(*) > 0;

-- RULE: SAL_003 - Salary Currency Valid ISO Codes
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SAL_003' AS rule_name,
  'Salary Validation' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_SET(salary_currency) AS invalid_currencies
FROM workspace.warehouse.fact_salary
WHERE salary_currency NOT IN ('USD', 'EUR', 'GBP', 'CAD', 'AUD', 'INR', 'JPY', 'CHF', 'CNY')
  AND salary_currency IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: SAL_004 - Salary Period Valid Values
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SAL_004' AS rule_name,
  'Salary Validation' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_SET(salary_period) AS invalid_periods
FROM workspace.warehouse.fact_salary
WHERE salary_period NOT IN ('ANNUAL', 'MONTHLY', 'HOURLY', 'WEEKLY', 'DAILY')
  AND salary_period IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: SAL_005 - Salary Confidence Score Range
-- Target: workspace.warehouse.fact_salary
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SAL_005' AS rule_name,
  'Salary Validation' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_LIST(fact_salary_sk) AS failed_ids
FROM workspace.warehouse.fact_salary
WHERE salary_confidence IS NOT NULL 
  AND (salary_confidence < 0 OR salary_confidence > 1)
HAVING COUNT(*) > 0;

-- RULE: SAL_006 - Annual Salary Reasonable Range
-- Target: workspace.warehouse.fact_salary
-- Severity: WARNING
-- Action: FLAG_FOR_REVIEW
SELECT 
  'SAL_006' AS rule_name,
  'Salary Validation' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_LIST(fact_salary_sk) AS failed_ids
FROM workspace.warehouse.fact_salary
WHERE salary_period = 'ANNUAL' 
  AND salary_currency = 'USD'
  AND (
    (salary_min IS NOT NULL AND (salary_min < 15000 OR salary_min > 1000000))
    OR (salary_max IS NOT NULL AND (salary_max < 15000 OR salary_max > 5000000))
  )
HAVING COUNT(*) > 0;

-- RULE: SAL_007 - Hourly Salary Reasonable Range
-- Target: workspace.warehouse.fact_salary
-- Severity: WARNING
-- Action: FLAG_FOR_REVIEW
SELECT 
  'SAL_007' AS rule_name,
  'Salary Validation' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_LIST(fact_salary_sk) AS failed_ids
FROM workspace.warehouse.fact_salary
WHERE salary_period = 'HOURLY' 
  AND salary_currency = 'USD'
  AND (
    (salary_min IS NOT NULL AND (salary_min < 7.25 OR salary_min > 500))
    OR (salary_max IS NOT NULL AND (salary_max < 7.25 OR salary_max > 1000))
  )
HAVING COUNT(*) > 0;

-- RULE: SAL_008 - Low Confidence Salary Data
-- Target: workspace.warehouse.fact_salary
-- Severity: WARNING
-- Action: FLAG_FOR_REVIEW
SELECT 
  'SAL_008' AS rule_name,
  'Salary Validation' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  COLLECT_LIST(fact_salary_sk) AS failed_ids
FROM workspace.warehouse.fact_salary
WHERE salary_observation_type = 'INFERRED' 
  AND salary_confidence < 0.5
HAVING COUNT(*) > 0;

-- RULE: SAL_009 - Salary Data Completeness by Sector
-- Target: workspace.warehouse.fact_salary
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SAL_009' AS rule_name,
  'Salary Validation' AS rule_category,
  'WARNING' AS severity,
  COUNT(DISTINCT ds.sector_name) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_salary' AS target_table,
  CONCAT('Sectors with < 10 salary observations: ', COLLECT_SET(ds.sector_name)) AS description
FROM workspace.warehouse.dim_sector ds
LEFT JOIN workspace.warehouse.fact_salary fs ON ds.sector_sk = fs.sector_sk
WHERE ds.active_flag = TRUE
GROUP BY ds.sector_sk, ds.sector_name
HAVING COUNT(fs.fact_salary_sk) < 10;

-- RULE: SAL_010 - Gold Salary Trends Data Quality
-- Target: workspace.gold.gold_salary_trends
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SAL_010' AS rule_name,
  'Salary Validation' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'gold' AS target_schema,
  'gold_salary_trends' AS target_table,
  'Salary trend records with inconsistent min/max/median values' AS description
FROM workspace.gold.gold_salary_trends
WHERE median_salary < min_salary 
   OR median_salary > max_salary
   OR min_salary > max_salary
HAVING COUNT(*) > 0;

-- RULE: SAL_011 - Missing Salary Data for Active Postings
-- Target: workspace.warehouse.fact_job_postings
-- Severity: INFO
-- Action: LOG_INFO
SELECT 
  'SAL_011' AS rule_name,
  'Salary Validation' AS rule_category,
  'INFO' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'fact_job_postings' AS target_table,
  ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM workspace.warehouse.fact_job_postings WHERE is_active = TRUE), 2) AS pct_missing_salary
FROM workspace.warehouse.fact_job_postings fjp
WHERE fjp.is_active = TRUE
  AND NOT EXISTS (
    SELECT 1 
    FROM workspace.warehouse.fact_salary fs
    WHERE fs.job_sk = fjp.job_sk
  )
HAVING COUNT(*) > 0;

-- =====================================================
-- END OF SALARY VALIDATIONS
-- =====================================================
