-- ============================================================================
-- Table: workspace.silver.silver_jobs_current
-- Layer: SILVER
-- Description: Current state of all job postings after CDC and deduplication. Single source of truth for job data.
-- ============================================================================
-- Purpose: Physical table definition for silver_jobs_current
-- Dependencies: workspace.silver.silver_jobs_staging
-- Consumers: workspace.warehouse.dim_job, workspace.warehouse.fact_job_postings
-- Expected Output: Table created with 22 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.silver.silver_jobs_current (
  enterprise_job_id STRING NOT NULL COMMENT 'Enterprise-wide unique job ID',
  source_name STRING NOT NULL COMMENT 'Source system name',
  source_job_id STRING NOT NULL COMMENT 'Job ID from source',
  source_job_key STRING NOT NULL COMMENT 'Composite source key',
  company_name_raw STRING COMMENT 'Raw company name',
  company_name_norm STRING COMMENT 'Normalized company name',
  title_raw STRING COMMENT 'Raw job title',
  title_normalized STRING COMMENT 'Standardized title',
  description_raw STRING COMMENT 'Job description text',
  location_norm STRING COMMENT 'Normalized location',
  remote_type STRING COMMENT 'Remote work type',
  salary_min DECIMAL(15,2) COMMENT 'Minimum salary',
  salary_max DECIMAL(15,2) COMMENT 'Maximum salary',
  salary_currency STRING COMMENT 'Salary currency code',
  employment_type_normalized STRING COMMENT 'Employment type',
  posted_at TIMESTAMP COMMENT 'Posting timestamp',
  last_seen TIMESTAMP NOT NULL COMMENT 'Last seen timestamp',
  is_active BOOLEAN NOT NULL COMMENT 'Currently active',
  soft_delete_flag BOOLEAN NOT NULL COMMENT 'Soft deleted',
  record_hash STRING NOT NULL COMMENT 'Content hash',
  created_at TIMESTAMP NOT NULL COMMENT 'First seen timestamp',
  updated_at TIMESTAMP NOT NULL COMMENT 'Last update timestamp'
,
  PRIMARY KEY (enterprise_job_id)
)
COMMENT 'Current state of all job postings after CDC and deduplication. Single source of truth for job data.'
PARTITIONED BY (updated_at)
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
