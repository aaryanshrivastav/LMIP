# LMIP Deployment Scripts

Automated deployment tools for the Labor Market Intelligence Platform (LMIP) on Databricks.

## Overview

This directory contains scripts to deploy the complete LMIP project to Databricks, including:
- Environment initialization (schemas, tables, metadata)
- Workspace assets (notebooks, files)
- Databricks Jobs (workflows)
- Validation of deployed components

## Directory Structure

```
deployment/
├── README.md                    # This file
├── README_INIT.md              # Initialization script documentation
├── .env.example                 # Environment variables template
├── init.py                      # Environment initialization (Step 0)
├── deploy_all.py               # Main orchestrator - deploys everything
├── deploy_workspace.py         # Deploy notebooks and files
├── deploy_jobs.py              # Deploy Databricks Jobs
├── validate_deployment.py      # Validate deployment
├── config.py                   # Configuration management
└── requirements.txt            # Python dependencies
```

## Prerequisites

### 1. Python Dependencies

Install required packages:

```bash
pip install -r requirements.txt
```

Key dependencies:
* `databricks-sdk` - Databricks SDK for Python
* `rich` - Console output formatting
* `requests` - HTTP requests for API validation

### 2. Databricks Authentication

Set up authentication using one of these methods:

**Option A: Environment Variables**
```bash
export DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"
export DATABRICKS_TOKEN="dapi..."
export DATABRICKS_WAREHOUSE_ID="your-warehouse-id"  # Optional
```

**Option B: Databricks CLI Configuration**
```bash
databricks configure --token
```

**Option C: .env File**
```bash
cp .env.example .env
# Edit .env with your credentials
```

### 3. Permissions

Ensure you have:
- Workspace access to create/modify notebooks and files
- Permission to create and manage Jobs
- Unity Catalog permissions (CREATE SCHEMA, CREATE TABLE)
- SQL Warehouse access (for initialization)

## Quick Start

### Full Deployment (Recommended)

Deploy everything in one command:

```bash
python deploy_all.py
```

This will:
0. **Initialize environment** - Create schemas, tables, and seed metadata
1. **Deploy workspace assets** - Upload notebooks from `../notebooks/` to workspace
2. **Create Jobs** - Set up workflows from `../workflows/*.json`
3. **Validate deployment** - Verify all components are properly configured

### Skip Initialization

If schemas and tables already exist:

```bash
python deploy_all.py --skip-init
```

### Dry Run

Preview what would be deployed without making changes:

```bash
python deploy_all.py --dry-run
```

### Update Existing Resources

Overwrite existing notebooks and jobs:

```bash
python deploy_all.py --update
```

## Environment Initialization

**NEW**: The `init.py` script consolidates the 5-notebook init workflow into a single Python script.

### Standalone Initialization

Run the initialization script directly:

```bash
# Initialize with default catalog (workspace)
python init.py

# Initialize with custom catalog
python init.py --catalog my_catalog

# Initialize with custom project root
python init.py --project-root /path/to/LMIP
```

### What It Does

1. **Creates Unity Catalog Schemas** - All 9 LMIP schemas (metadata, bronze, silver, intermediate, gold, reporting, audit, publish, quarantine)
2. **Executes DDL Files** - Creates 40+ tables in correct dependency order
3. **Seeds Metadata Tables** - Loads CSV files for canonical roles, skills, sectors, and families
4. **Validates Environment** - Checks Python version, packages, schemas, and API connectivity

### Key Features

* **Idempotent** - Safe to run multiple times
* **SDK-Based** - Uses Databricks SDK (no notebook dependencies)
* **Dependency-Aware** - Executes DDL in correct order
* **Rich Output** - Colored console output with status indicators

For detailed documentation, see [README_INIT.md](README_INIT.md).

## Individual Deployment Scripts

### Deploy Workspace Assets

Deploy notebooks and files only:

```bash
# Deploy all notebooks
python deploy_workspace.py

# Preview changes
python deploy_workspace.py --dry-run

# Update existing notebooks
python deploy_workspace.py --update

# Deploy from custom directory
python deploy_workspace.py --source-dir /path/to/notebooks --target-path /workspace/path
```

### Deploy Jobs

Deploy Databricks Jobs from workflow definitions:

```bash
# Deploy all workflow JSON files
python deploy_jobs.py

# Deploy specific workflow
python deploy_jobs.py --workflow init.json

# Update existing jobs
python deploy_jobs.py --update

# Dry run
python deploy_jobs.py --dry-run
```

### Validate Deployment

Check that all components are properly deployed:

```bash
python validate_deployment.py
```

Validates:
- Unity Catalog schemas (bronze, silver, intermediate, gold, reporting, metadata, audit, publish, quarantine)
- Critical tables (bronze_job_snapshot, silver_jobs_current, dim_company, etc.)
- Core notebooks (ingestion, init, helpers)
- Databricks Jobs (initialization, daily ingestion)

## Configuration

### Environment Variables

Edit `.env` (copy from `.env.example`):

```bash
# Databricks Connection
DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
DATABRICKS_TOKEN=dapi...
DATABRICKS_WAREHOUSE_ID=your-warehouse-id  # Optional, auto-selects if not provided

# Workspace Paths
WORKSPACE_ROOT=/Users/your.email@company.com/LMIP

# Unity Catalog
CATALOG=workspace
BRONZE_SCHEMA=bronze
SILVER_SCHEMA=silver
INTERMEDIATE_SCHEMA=intermediate
GOLD_SCHEMA=gold
REPORTING_SCHEMA=reporting
METADATA_SCHEMA=metadata
AUDIT_SCHEMA=audit
PUBLISH_SCHEMA=publish
QUARANTINE_SCHEMA=quarantine

# Notifications
NOTIFICATION_EMAIL=your.email@company.com

# Compute
USE_SERVERLESS=true
```

### Configuration in Code

The `config.py` module provides centralized configuration management:

```python
from config import get_config

config = get_config()
config.print_summary()
```

## Workflow Definitions

Workflow JSON files in `../workflows/` follow the Databricks Jobs API format:

```json
{
  "name": "My_Job",
  "tasks": [
    {
      "task_key": "my_task",
      "notebook_task": {
        "notebook_path": "/path/to/notebook",
        "base_parameters": {
          "catalog": "workspace"
        }
      }
    }
  ],
  "email_notifications": {
    "on_failure": ["your.email@company.com"]
  }
}
```

## Deployment Workflow

### Step-by-Step Deployment

For a controlled deployment, run each step individually:

```bash
# Step 0: Initialize environment (schemas, tables, metadata)
python init.py

# Step 1: Deploy workspace assets
python deploy_workspace.py

# Step 2: Deploy Databricks Jobs
python deploy_jobs.py

# Step 3: Validate deployment
python validate_deployment.py
```

### CI/CD Integration

The deployment scripts are designed for CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
- name: Deploy LMIP to Databricks
  run: |
    pip install -r deployment/requirements.txt
    python deployment/deploy_all.py
  env:
    DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
    DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
```

## Troubleshooting

### "No SQL warehouses found"

**Solution**: Set `DATABRICKS_WAREHOUSE_ID` environment variable or create a SQL warehouse in your workspace.

### "DDL directory not found"

**Solution**: Run from project root or specify `--project-root`:
```bash
python deployment/init.py --project-root /path/to/LMIP
```

### "Permission denied" errors

**Solution**: Ensure you have:
- `CREATE SCHEMA` permission on the Unity Catalog
- `CREATE TABLE` permission on schemas
- Workspace permissions to create notebooks/jobs

### Package import errors

**Solution**: Install dependencies:
```bash
pip install -r deployment/requirements.txt
```

## Migration Notes

### From Notebook-Based Init (Pre-2024)

The new `init.py` script replaces the 5-notebook initialization workflow:

| Old (Notebooks) | New (Python Script) |
|----------------|---------------------|
| 5 separate notebooks | 1 Python script |
| Manual orchestration | Single command |
| dbutils dependencies | Databricks SDK only |
| Hard to CI/CD integrate | Easy CI/CD integration |

**Migration**: Simply run `python init.py` instead of executing init notebooks. The script is fully backward-compatible and idempotent.

## Related Documentation

* [README_INIT.md](README_INIT.md) - Detailed initialization script documentation
* [../notebooks/MIGRATION_PROGRESS.md](../notebooks/MIGRATION_PROGRESS.md) - Notebook migration status
* [../sql/ddl/README.md](../sql/ddl/README.md) - DDL file documentation
* [../metadata/README.md](../metadata/README.md) - Metadata seed data documentation

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review detailed docs in [README_INIT.md](README_INIT.md)
3. Check logs in the console output (rich formatting enabled)

---

**Last Updated**: December 2024  
**LMIP Version**: 1.0  
**Databricks SDK**: >= 0.18.0
