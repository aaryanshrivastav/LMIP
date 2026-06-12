-- ============================================================================
-- Bootstrap Script: Create Schemas
-- Purpose: Initialize all schemas required for LMIP data warehouse
-- Expected Output: 9 schemas created (bronze, silver, semantic, warehouse, gold, quarantine, publish, audit, metadata)
-- Dependencies: workspace catalog must exist
-- ============================================================================

-- Create Bronze Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.bronze
COMMENT 'Bronze layer - raw immutable data from source systems'
LOCATION 'dbfs:/lmip/bronze';

-- Create Silver Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.silver
COMMENT 'Silver layer - cleaned, standardized, and deduplicated data'
LOCATION 'dbfs:/lmip/silver';

-- Create Semantic Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.semantic
COMMENT 'Semantic layer - business logic and canonical mappings'
LOCATION 'dbfs:/lmip/semantic';

-- Create Warehouse Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.warehouse
COMMENT 'Warehouse layer - dimensional model with facts and dimensions'
LOCATION 'dbfs:/lmip/warehouse';

-- Create Gold Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.gold
COMMENT 'Gold layer - aggregated analytical marts and views'
LOCATION 'dbfs:/lmip/gold';

-- Create Quarantine Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.quarantine
COMMENT 'Quarantine layer - records that failed data quality validation'
LOCATION 'dbfs:/lmip/quarantine';

-- Create Publish Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.publish
COMMENT 'Publish layer - consumer-facing exports, manifests, and bundles'
LOCATION 'dbfs:/lmip/publish';

-- Create Audit Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.audit
COMMENT 'Audit layer - pipeline metadata, data quality results, and access logs'
LOCATION 'dbfs:/lmip/audit';

-- Create Metadata Layer Schema
CREATE SCHEMA IF NOT EXISTS workspace.metadata
COMMENT 'Metadata layer - pipeline control, source configuration, and batch tracking'
LOCATION 'dbfs:/lmip/metadata';

-- Verify schemas were created
SELECT 
  schema_name,
  schema_owner,
  comment
FROM system.information_schema.schemata
WHERE catalog_name = 'workspace'
  AND schema_name IN ('bronze', 'silver', 'semantic', 'warehouse', 'gold', 'quarantine', 'publish', 'audit', 'metadata')
ORDER BY schema_name;

-- End of bootstrap script
