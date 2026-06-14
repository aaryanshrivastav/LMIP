# LMIP Initialization Script

**Location**: `deployment/init.py`

**Purpose**: Consolidated Python script that replaces the 5-notebook init workflow with a single runnable script using the Databricks SDK.

---

## Overview

The `init.py` script consolidates all initialization notebooks (`init_create_schemas`, `init_seed_metadata`, `init_validate_env`, etc.) into a single Python script that can be run from the command line or imported as a module.

### What It Does

1. **Creates Unity Catalog Schemas** - All 9 LMIP schemas (metadata, bronze, silver, intermediate, gold, reporting, audit, publish, quarantine)
2. **Executes DDL Files** - Creates all tables in correct dependency order (40+ DDL files)
3. **Seeds Metadata Tables** - Loads CSV files for canonical roles, skills, sectors, and families
4. **Validates Environment** - Checks Python version, packages, schemas, tables, and API connectivity

### Key Features

* **Idempotent** - Safe to run multiple times without causing errors
* **SDK-Based** - Uses `databricks.sdk` for direct SQL execution (no notebook dependencies)
* **Dependency-Aware** - Executes DDL files in correct order to respect table dependencies
* **Rich Output** - Colored console output with clear status indicators (✓, ⚠, ✗)
* **Error Handling** - Continues on non-critical errors, reports all issues at the end

---

## Usage

### 1. Standalone Execution

Run directly from the command line:

```bash
# Initialize with default catalog (workspace)
python deployment/init.py

# Initialize with custom catalog
python deployment/init.py --catalog my_catalog

# Initialize with custom project root
python deployment/init.py --project-root /path/to/LMIP
```

### 2. Programmatic Usage (from deploy_all.py)

Import and call from other deployment scripts:

```python
from deployment.init import LMIPInitializer

# Create initializer
initializer = LMIPInitializer(
    catalog="workspace",
    project_root=Path("/path/to/LMIP")
)

# Run initialization
success = initializer.initialize()

if success:
    print("Environment ready!")
else:
    print("Initialization completed with warnings")
```

### 3. Integrated Deployment

The `deploy_all.py` script now calls `init.py` automatically as **Step 0**:

```bash
# Full deployment (init + workspace + jobs + validation)
python deployment/deploy_all.py

# Skip initialization if schemas/tables already exist
python deployment/deploy_all.py --skip-init
```

---

## Prerequisites

### Required Packages

Install via pip:

```bash
pip install databricks-sdk rich requests
```

Or install all deployment requirements:

```bash
pip install -r deployment/requirements.txt
```

### Databricks Authentication

Set environment variables:

```bash
export DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"
export DATABRICKS_TOKEN="dapi..."
export DATABRICKS_WAREHOUSE_ID="your-warehouse-id"  # Optional
```

Or use `.env` file in `deployment/` directory.

### Required Files

The script expects the following directory structure:

```
LMIP/
├── deployment/
│   └── init.py
├── sql/
│   └── ddl/
│       ├── metadata_source_config.sql
│       ├── bronze_bronze_job_snapshot.sql
│       └── ... (40+ DDL files)
└── metadata/
    ├── canonical_roles.csv
    ├── canonical_skills.csv
    ├── sectors.csv
    └── role_families.csv
```

---

## Execution Flow

### Step 1: Create Schemas (9 schemas)

Creates all Unity Catalog schemas using `CREATE SCHEMA IF NOT EXISTS`:

* metadata
* bronze
* silver
* intermediate
* gold
* reporting
* audit
* publish
* quarantine

### Step 2: Execute DDL Files (40+ tables)

Runs DDL files in dependency order:

1. **Metadata Layer** - `source_config`, `pipeline_run_control`
2. **Audit & Quarantine** - `audit_pipeline_runs`, `quarantine_jobs`
3. **Bronze Layer** - `bronze_job_snapshot`, `bronze_api_response_log`
4. **Silver Layer** - `silver_jobs_current`, `silver_jobs_history`
5. **Intermediate Layer** - `inter_company_canonical`, `inter_skill_catalog`
6. **Gold/Warehouse Layer** - Dimensions (`dim_company`, `dim_role`) and facts
7. **Publish Layer** - `publish_manifest`, `publish_bundle_log`

### Step 3: Seed Metadata (4 CSV files)

Loads seed data from CSV files:

* `canonical_roles.csv` → `metadata.taxonomy_role_canonical`
* `role_families.csv` → `metadata.taxonomy_role_families`
* `sectors.csv` → `metadata.taxonomy_sectors`
* `canonical_skills.csv` → `metadata.taxonomy_skill_catalog`

### Step 4: Validate Environment

Checks:

* Python version (≥ 3.10 recommended)
* Required packages (databricks-sdk, requests, rich)
* Schema existence (all 9 schemas)
* Network connectivity (API endpoints)

---

## Exit Status

* **0** - Success (all steps completed without errors)
* **1** - Failure (one or more steps encountered errors)

Warnings (e.g., API timeout, recommended Python version) do not cause failure.

---

## Advantages Over Notebook-Based Init

### Before (5 notebooks)

* ❌ Required notebook orchestration (`dbutils.notebook.run()`)
* ❌ Dependent on Databricks notebook runtime
* ❌ Hard to integrate with CI/CD pipelines
* ❌ Manual execution of each notebook
* ❌ Difficult to version control execution logic

### After (1 Python script)

* ✅ Single file, single command
* ✅ Uses Databricks SDK (runs anywhere Python runs)
* ✅ Easy CI/CD integration
* ✅ Automatic execution via `deploy_all.py`
* ✅ Standard Python packaging and imports

---

## DDL Execution Order

The script executes DDL files in this order to respect dependencies:

```
Metadata (3 files)
  ↓
Audit + Quarantine (6 files)
  ↓
Bronze (2 files)
  ↓
Silver (4 files)
  ↓
Intermediate (6 files)
  ↓
Warehouse Dimensions (7 files)
  ↓
Warehouse Bridges + Facts (2 files)
  ↓
Gold Aggregates (2 files)
  ↓
Publish (2 files)
```

---

## Troubleshooting

### "No SQL warehouses found"

**Solution**: Set `DATABRICKS_WAREHOUSE_ID` environment variable:

```bash
export DATABRICKS_WAREHOUSE_ID="your-warehouse-id"
```

Or create a SQL warehouse in your Databricks workspace.

### "DDL directory not found"

**Solution**: Run from project root or specify `--project-root`:

```bash
python deployment/init.py --project-root /path/to/LMIP
```

### "Table already exists" errors

This is **expected behavior**. The script uses `CREATE TABLE IF NOT EXISTS`, so existing tables are skipped without error.

### Package import errors

**Solution**: Install dependencies:

```bash
pip install -r deployment/requirements.txt
```

---

## Comparison to Original Notebooks

| Feature | Notebooks (Old) | init.py (New) |
|---------|----------------|---------------|
| **Files** | 5 notebooks | 1 Python script |
| **Execution** | Manual or via orchestration | Single command |
| **Dependencies** | dbutils, notebook runtime | Databricks SDK only |
| **CI/CD Integration** | Difficult | Easy |
| **Idempotent** | Yes | Yes |
| **Validation** | Separate notebook | Integrated |
| **Error Handling** | Per-notebook | Unified |
| **Output Format** | Notebook HTML | Rich console |

---

## Integration Points

### Called By

* `deployment/deploy_all.py` - Step 0 of full deployment

### Calls

* Databricks SDK `statement_execution.execute_statement()` - For SQL execution
* Local filesystem - Reads DDL files and CSV metadata

### Configuration

* `catalog` - Unity Catalog name (default: "workspace")
* `project_root` - LMIP project root directory (default: auto-detect)
* `DATABRICKS_HOST` - Workspace URL (from environment)
* `DATABRICKS_TOKEN` - Authentication token (from environment)
* `DATABRICKS_WAREHOUSE_ID` - SQL warehouse (from environment, optional)

---

## Future Enhancements

* Add `--verify-only` flag for schema/table verification without creation
* Add `--catalog-mapping` for multi-catalog deployments
* Add `--parallel` for parallel DDL execution (where dependencies allow)
* Add detailed logging to file for audit trails
* Add rollback capability for failed initializations

---

## See Also

* [deployment/deploy_all.py](deploy_all.py) - Full deployment orchestrator
* [deployment/README.md](README.md) - Deployment guide
* [notebooks/init/README_INIT.md](../notebooks/init/README_INIT.md) - Original notebook documentation
