-- ============================================================================
-- Table: workspace.silver.silver_skill_mapping
-- Layer: SILVER
-- Description: Extracted skills from job descriptions with evidence and confidence scores
-- ============================================================================
-- Purpose: Physical table definition for silver_skill_mapping
-- Dependencies: workspace.silver.silver_jobs_current
-- Consumers: workspace.semantic.sem_skill_catalog, workspace.warehouse.bridge_job_skill
-- Expected Output: Table created with 9 columns
-- ============================================================================

CREATE TABLE IF NOT EXISTS workspace.silver.silver_skill_mapping (
  skill_mapping_id STRING NOT NULL COMMENT 'Unique mapping ID',
  enterprise_job_id STRING NOT NULL COMMENT 'Job identifier',
  skill_name_raw STRING NOT NULL COMMENT 'Skill as extracted from text',
  skill_name_normalized STRING NOT NULL COMMENT 'Canonical skill name',
  extraction_method STRING NOT NULL COMMENT 'KEYWORD, PATTERN, NLP',
  evidence_text STRING COMMENT 'Text snippet showing skill mention',
  confidence DECIMAL(5,4) NOT NULL COMMENT 'Extraction confidence 0-1',
  batch_id STRING NOT NULL COMMENT 'Processing batch ID',
  extracted_at TIMESTAMP NOT NULL COMMENT 'Extraction timestamp'
,
  PRIMARY KEY (skill_mapping_id)
)
COMMENT 'Extracted skills from job descriptions with evidence and confidence scores'
USING DELTA
TBLPROPERTIES (
  'delta.enableChangeDataFeed' = 'true',
  'delta.autoOptimize.optimizeWrite' = 'true',
  'delta.autoOptimize.autoCompact' = 'true'
);

-- End of DDL
