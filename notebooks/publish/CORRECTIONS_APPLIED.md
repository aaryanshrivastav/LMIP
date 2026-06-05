# LMIP Publish Notebooks - Catalog & Table Corrections

**Date**: June 4, 2026

## Summary

All publish notebooks have been updated to reference the correct catalogs, schemas, and tables from the LMIP project.

## Key Changes

### 1. Schema Organization

**Before**: All tables incorrectly assumed to be in `workspace.gold`

**After**: Proper three-tier organization:
* `workspace.warehouse.*` - Dimensional model (dimensions, facts, bridges)
* `workspace.gold.*` - Analytics marts and aggregates
* `workspace.audit.*` - Audit and logging tables

### 2. Warehouse Layer Tables (13 total)

**Dimensions** (8):
* dim_source (source_sk)
* dim_sector (sector_sk)
* dim_role (role_sk)
* dim_location (location_sk)
* dim_company (company_sk)
* dim_skill (skill_sk)
* dim_job (job_sk)
* dim_company_alias (composite key)

**Facts** (4):
* fact_job_postings (fact_job_posting_sk) ✓ Fixed PK name
* fact_job_lifecycle (fact_job_lifecycle_sk)
* fact_salary (fact_salary_sk)
* fact_pipeline_runs (fact_pipeline_run_sk)

**Bridges** (1):
* bridge_job_skill (composite key)

### 3. Gold Layer Tables (10 total)

**Updated/Added**:
* gold_hiring_trends ✓
* gold_sector_overview (was gold_sector_metrics) ✓ Fixed
* gold_location_trends (was gold_location_heatmap) ✓ Fixed
* gold_company_hiring
* gold_salary_trends
* gold_skill_demand
* gold_hospitality_companies
* gold_hospitality_hiring
* gold_hospitality_skills
* gold_pipeline_health

### 4. Audit Layer Tables (3 total)

**Updated**:
* audit_pipeline_runs ✓
* audit_dq_results (was audit_data_quality_log) ✓ Fixed
* audit_access_events
* ~~audit_source_freshness~~ ✗ Removed (doesn't exist)

## Notebooks Updated

### 1. publish_supabase_upsert.ipynb
* Added `WAREHOUSE_SCHEMA = "warehouse"`
* Updated table tuple structure: `(table, schema, pk, deps)`
* Fixed `fact_job_postings` primary key: `posting_sk` → `fact_job_posting_sk`
* Expanded table list from 9 to 26 tables
* Updated sync loop to use schema field from tuple

### 2. publish_csv_snapshot_export.ipynb
* Added `WAREHOUSE_SCHEMA = "warehouse"`
* Updated export configuration with 37 table entries
* Corrected sort columns for all tables
* Added proper schema routing for warehouse/gold/audit

### 3. publish_manifest_write.ipynb
* Added `WAREHOUSE_SCHEMA = "warehouse"`
* Updated TABLE_DEFINITIONS with schema field
* Fixed tuple unpacking: added schema parameter
* Expanded from 12 to 26 table definitions
* Updated dependency graph generation

### 4. publish_load_order_check.ipynb
* Added `WAREHOUSE_SCHEMA = "warehouse"`
* Updated schema detection logic:
  * `audit_*` → audit schema
  * `gold_*` → gold schema
  * `dim_*`, `fact_*`, `bridge_*` → warehouse schema
* Fixed row count validation to use correct schemas

## Validation

All table references validated against Unity Catalog:

```sql
-- Verified schemas exist
SHOW SCHEMAS IN workspace;
-- Results: warehouse, gold, audit (plus others)

-- Verified warehouse tables
SHOW TABLES IN workspace.warehouse;
-- 13 tables confirmed

-- Verified gold tables
SHOW TABLES IN workspace.gold;
-- 20 tables total (10 included in publication)

-- Verified audit tables
SHOW TABLES IN workspace.audit;
-- 3 tables confirmed
```

## Load Order & Dependencies

**Phase 1**: Warehouse Dimensions (no dependencies)
→ dim_source, dim_sector, dim_role, dim_location, dim_company, dim_skill, dim_job, dim_company_alias

**Phase 2**: Warehouse Facts (depend on dimensions)
→ fact_job_postings, fact_job_lifecycle, fact_salary, fact_pipeline_runs

**Phase 3**: Warehouse Bridges (depend on dimensions)
→ bridge_job_skill

**Phase 4**: Gold Marts (depend on warehouse)
→ gold_hiring_trends, gold_sector_overview, gold_location_trends, etc.

**Phase 5**: Audit (independent)
→ audit_pipeline_runs, audit_dq_results, audit_access_events

## Testing Recommendations

1. **Dry Run**: Test export on a small subset of tables first
2. **Schema Validation**: Verify all table schemas are accessible
3. **Row Count Check**: Run validation notebook on existing snapshots
4. **Dependency Check**: Verify no circular dependencies in updated graph
5. **Supabase Test**: Test upsert on non-production Supabase instance first

## Known Limitations

* Some gold tables may have composite keys - set primary_key=None for these
* Sort columns for some gold tables are assumed - verify before production export
* Not all existing gold tables are included (selective publication)

## Next Steps

1. Review table selection for publication (currently 26 tables)
2. Verify sort columns for deterministic exports
3. Test full pipeline on dev environment
4. Update README.md with actual table list
5. Create Databricks Job for scheduled publication
