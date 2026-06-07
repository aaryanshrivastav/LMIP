-- ============================================================================
-- Validation Script: Referential Integrity Validation
-- Purpose: Validate foreign key relationships across all layers
-- Expected Output: List of orphaned records (child records with missing parent)
-- Dependencies: All dimension and fact tables with FK relationships
-- ============================================================================

-- Fact to Dimension Referential Integrity Checks

-- fact_job_postings -> dim_job
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS child_table,
  'job_sk' AS fk_column,
  'dim_job' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings f
LEFT JOIN workspace.warehouse.dim_job d ON f.job_sk = d.job_sk
WHERE d.job_sk IS NULL

UNION ALL

-- fact_job_postings -> dim_company
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS child_table,
  'company_sk' AS fk_column,
  'dim_company' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings f
LEFT JOIN workspace.warehouse.dim_company d ON f.company_sk = d.company_sk
WHERE d.company_sk IS NULL

UNION ALL

-- fact_job_postings -> dim_location
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS child_table,
  'location_sk' AS fk_column,
  'dim_location' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings f
LEFT JOIN workspace.warehouse.dim_location d ON f.location_sk = d.location_sk
WHERE d.location_sk IS NULL

UNION ALL

-- fact_job_postings -> dim_role
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS child_table,
  'role_sk' AS fk_column,
  'dim_role' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings f
LEFT JOIN workspace.warehouse.dim_role d ON f.role_sk = d.role_sk
WHERE d.role_sk IS NULL

UNION ALL

-- fact_job_postings -> dim_sector
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS child_table,
  'sector_sk' AS fk_column,
  'dim_sector' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings f
LEFT JOIN workspace.warehouse.dim_sector d ON f.sector_sk = d.sector_sk
WHERE d.sector_sk IS NULL

UNION ALL

-- fact_job_postings -> dim_source
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS child_table,
  'source_sk' AS fk_column,
  'dim_source' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings f
LEFT JOIN workspace.warehouse.dim_source d ON f.source_sk = d.source_sk
WHERE d.source_sk IS NULL

UNION ALL

-- fact_job_postings -> dim_date
SELECT
  'WAREHOUSE' AS layer,
  'fact_job_postings' AS child_table,
  'posting_date_sk' AS fk_column,
  'dim_date' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.fact_job_postings f
LEFT JOIN workspace.warehouse.dim_date d ON f.posting_date_sk = d.date_sk
WHERE d.date_sk IS NULL

UNION ALL

-- bridge_job_skill -> dim_job
SELECT
  'WAREHOUSE' AS layer,
  'bridge_job_skill' AS child_table,
  'job_sk' AS fk_column,
  'dim_job' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.bridge_job_skill b
LEFT JOIN workspace.warehouse.dim_job d ON b.job_sk = d.job_sk
WHERE d.job_sk IS NULL

UNION ALL

-- bridge_job_skill -> dim_skill
SELECT
  'WAREHOUSE' AS layer,
  'bridge_job_skill' AS child_table,
  'skill_sk' AS fk_column,
  'dim_skill' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.bridge_job_skill b
LEFT JOIN workspace.warehouse.dim_skill d ON b.skill_sk = d.skill_sk
WHERE d.skill_sk IS NULL

UNION ALL

-- dim_job -> dim_company
SELECT
  'WAREHOUSE' AS layer,
  'dim_job' AS child_table,
  'company_sk' AS fk_column,
  'dim_company' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.warehouse.dim_job j
LEFT JOIN workspace.warehouse.dim_company c ON j.company_sk = c.company_sk
WHERE j.company_sk IS NOT NULL AND c.company_sk IS NULL

UNION ALL

-- Silver to Silver referential checks
-- silver_jobs_current -> dim_source (if exists)
SELECT
  'SILVER' AS layer,
  'silver_jobs_current' AS child_table,
  'source_name' AS fk_column,
  'dim_source' AS parent_table,
  COUNT(*) AS orphaned_records,
  CURRENT_TIMESTAMP() AS validation_timestamp
FROM workspace.silver.silver_jobs_current s
LEFT JOIN workspace.warehouse.dim_source d ON s.source_name = d.source_name
WHERE d.source_name IS NULL

ORDER BY layer, child_table, fk_column;