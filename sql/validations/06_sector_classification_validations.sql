-- =====================================================
-- LMIP Data Quality Framework
-- Sector Classification Validation Rules
-- =====================================================
-- Purpose: Validate sector assignments and classifications
-- Severity: WARNING for missing, ERROR for invalid
-- =====================================================

-- RULE: SECT_001 - Missing Sector Assignment
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: QUEUE_FOR_SEMANTIC_REVIEW
SELECT 
  'SECT_001' AS rule_name,
  'Sector Classification' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE is_active = TRUE 
  AND sector_assigned IS NULL
HAVING COUNT(*) > 0;

-- RULE: SECT_002 - Low Confidence Sector Assignment
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: QUEUE_FOR_SEMANTIC_REVIEW
SELECT 
  'SECT_002' AS rule_name,
  'Sector Classification' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE is_active = TRUE 
  AND sector_confidence < 0.6
  AND sector_assigned IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: SECT_003 - Sector Assignment Without Semantic Mapping
-- Target: workspace.silver.silver_jobs_current
-- Severity: ERROR
-- Action: CREATE_SEMANTIC_MAPPING
SELECT 
  'SECT_003' AS rule_name,
  'Sector Classification' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current sj
WHERE sj.sector_assigned IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 
    FROM workspace.semantic.sem_sector_map ssm
    WHERE ssm.enterprise_job_id = sj.enterprise_job_id
  )
HAVING COUNT(*) > 0;

-- RULE: SECT_004 - Invalid Sector Code in Semantic Layer
-- Target: workspace.semantic.sem_sector_map
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'SECT_004' AS rule_name,
  'Sector Classification' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  COLLECT_LIST(sector_map_id) AS failed_ids
FROM workspace.semantic.sem_sector_map ssm
WHERE ssm.canonical_sector_code IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 
    FROM workspace.warehouse.dim_sector ds
    WHERE ds.sector_name = ssm.canonical_sector_name
      OR ARRAY_CONTAINS(ds.sector_aliases, ssm.canonical_sector_name)
  )
HAVING COUNT(*) > 0;

-- RULE: SECT_005 - Sector Assignment Method Missing
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SECT_005' AS rule_name,
  'Sector Classification' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE sector_assigned IS NOT NULL 
  AND sector_assignment_method IS NULL
HAVING COUNT(*) > 0;

-- RULE: SECT_006 - Normalization Method Valid Values
-- Target: workspace.semantic.sem_sector_map
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SECT_006' AS rule_name,
  'Sector Classification' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  COLLECT_SET(normalization_method) AS invalid_values
FROM workspace.semantic.sem_sector_map
WHERE normalization_method NOT IN ('ML_MODEL', 'RULE_BASED', 'MANUAL', 'LOOKUP', 'AI_INFERENCE')
  AND normalization_method IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: SECT_007 - Taxonomy Type Valid Values
-- Target: workspace.semantic.sem_sector_map
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SECT_007' AS rule_name,
  'Sector Classification' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'semantic' AS target_schema,
  'sem_sector_map' AS target_table,
  COLLECT_SET(taxonomy_type) AS invalid_values
FROM workspace.semantic.sem_sector_map
WHERE taxonomy_type NOT IN ('NAICS', 'SIC', 'CUSTOM', 'INDUSTRY_STANDARD')
  AND taxonomy_type IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: SECT_008 - Sector Family Consistency in Warehouse
-- Target: workspace.warehouse.dim_sector
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SECT_008' AS rule_name,
  'Sector Classification' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_sector' AS target_table,
  'Sectors with invalid sector_family values' AS description
FROM workspace.warehouse.dim_sector
WHERE sector_family NOT IN (
  SELECT DISTINCT sector_family 
  FROM workspace.warehouse.dim_sector
  WHERE active_flag = TRUE
  GROUP BY sector_family
  HAVING COUNT(*) > 1
)
HAVING COUNT(*) > 0;

-- RULE: SECT_009 - Hospitality Sector Coverage
-- Target: workspace.gold.gold_hospitality_companies
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'SECT_009' AS rule_name,
  'Sector Classification' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'gold' AS target_schema,
  'gold_hospitality_companies' AS target_table,
  'Companies tagged as hospitality missing sector assignment' AS description
FROM workspace.gold.gold_hospitality_companies ghc
WHERE NOT EXISTS (
  SELECT 1 
  FROM workspace.warehouse.dim_company dc
  JOIN workspace.warehouse.fact_job_postings fjp ON dc.company_sk = fjp.company_sk
  JOIN workspace.warehouse.dim_sector ds ON fjp.sector_sk = ds.sector_sk
  WHERE dc.company_name = ghc.company_name
    AND ds.sector_family = 'HOSPITALITY'
)
HAVING COUNT(*) > 0;

-- =====================================================
-- END OF SECTOR CLASSIFICATION VALIDATIONS
-- =====================================================
