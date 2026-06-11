# LMIP Deployment Scripts

Automated deployment tools for the Labor Market Intelligence Platform (LMIP) on Databricks.

## Overview

This directory contains scripts to deploy the complete LMIP project to Databricks, including:
- Workspace assets (notebooks, files)
- Databricks Jobs (workflows)
- Validation of deployed components

## Directory Structure

```
deployment/
├── README.md                    # This file
├── .env.example                 # Environment variables template
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

### 2. Databricks Authentication

Set up authentication using one of these methods:

**Option A: Environment Variables**
```bash
export DATABRICKS_HOST="https://your-workspace.cloud.databricks.com"
export DATABRICKS_TOKEN="dapi..."
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
- Unity Catalog permissions (if using custom catalog)

## Quick Start

### Full Deployment

Deploy everything in one command:

```bash
python deploy_all.py
```

This will:
1. Deploy all notebooks from `../notebooks/` to workspace
2. Create Databricks Jobs from `../workflows/*.json`
3. Validate the deployment

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
- Unity Catalog schemas (bronze, silver, gold, metadata, audit)
- Critical tables (bronze_job_snapshot, audit_pipeline_runs, etc.)
- Core notebooks (ingestion, init, helpers)
- Databricks Jobs (initialization, daily ingestion)

## Configuration

### Environment Variables

Edit `.env` (copy from `.env.example`):

```bash
# Databricks Connection
DATABRICKS_HOST=https://your-workspace.cloud.databricks.com
DATABRICKS_TOKEN=dapi...

# Workspace Paths
WORKSPACE_ROOT=/Users/your.email@company.com/LMIP

# Unity Catalog
CATALOG=workspace
BRONZE_SCHEMA=bronze
SILVER_SCHEMA=silver
GOLD_SCHEMA=gold
METADATA_SCHEMA=metadata
AUDIT_SCHEMA=audit

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

The deployment script will:
- Normalize notebook paths
- Substitute configuration parameters
- Create or update jobs as needed

## Command Reference

### deploy_all.py

Main orchestrator for complete deployment.

**Options:**
- `--dry-run`: Preview changes without deploying
- `--update`: Update existing resources
- `--force`: Continue even if errors occur
- `--skip-validation`: Skip validation step

**Examples:**
```bash
# Full deployment with updates
python deploy_all.py --update

# Dry run
python deploy_all.py --dry-run

# Skip validation
python deploy_all.py --skip-validation
```

### deploy_workspace.py

Deploy notebooks and workspace files.

**Options:**
- `--update`: Overwrite existing files
- `--dry-run`: Preview changes
- `--source-dir PATH`: Source directory (default: ../notebooks)
- `--target-path PATH`: Target workspace path

**Examples:**
```bash
# Deploy notebooks
python deploy_workspace.py

# Update existing
python deploy_workspace.py --update

# Custom paths
python deploy_workspace.py --source-dir ./my-notebooks --target-path /Custom/Path
```

### deploy_jobs.py

Deploy Databricks Jobs from workflow definitions.

**Options:**
- `--update`: Update existing jobs
- `--dry-run`: Preview changes
- `--workflow FILE`: Deploy specific workflow
- `--workflow-dir PATH`: Workflow directory (default: ../workflows)

**Examples:**
```bash
# Deploy all workflows
python deploy_jobs.py

# Deploy specific workflow
python deploy_jobs.py --workflow init.json

# Update existing
python deploy_jobs.py --update
```

### validate_deployment.py

Validate deployment completeness.

**Options:**
- `--verbose`: Show detailed output

**Examples:**
```bash
# Run validation
python validate_deployment.py

# Verbose output
python validate_deployment.py --verbose
```

## Troubleshooting

### Authentication Issues

```
Error: Could not authenticate to Databricks
```

**Solution:** Check your credentials:
```bash
# Verify environment variables
echo $DATABRICKS_HOST
echo $DATABRICKS_TOKEN

# Or check Databricks CLI config
cat ~/.databrickscfg
```

### Permission Errors

```
Error: User does not have permission to create jobs
```

**Solution:** Contact your workspace admin to grant necessary permissions.

### Notebook Not Found

```
Error: Notebook not found at /path/to/notebook
```

**Solution:** 
1. Check that notebooks exist in `../notebooks/` directory
2. Verify workspace paths in workflow JSON files
3. Run `deploy_workspace.py` first to deploy notebooks

### Job Already Exists

```
Job already exists (ID: 12345). Use --update to modify.
```

**Solution:** Use `--update` flag to overwrite existing jobs:
```bash
python deploy_jobs.py --update
```

### Schema Not Found

```
Error: Schema 'bronze' not found
```

**Solution:** Run the initialization job first:
1. Deploy jobs: `python deploy_jobs.py`
2. Run initialization job from Databricks UI: **LMIP_Initialization**

## Best Practices

### Development Workflow

1. **Test changes locally first:**
   ```bash
   python deploy_all.py --dry-run
   ```

2. **Deploy to dev workspace:**
   ```bash
   # Edit .env to point to dev workspace
   python deploy_all.py --update
   ```

3. **Validate deployment:**
   ```bash
   python validate_deployment.py
   ```

4. **Deploy to production:**
   ```bash
   # Edit .env to point to prod workspace
   python deploy_all.py
   ```

### Incremental Updates

For single notebook updates:
```bash
python deploy_workspace.py --update
```

For single job updates:
```bash
python deploy_jobs.py --workflow my_job.json --update
```

### Version Control

- Keep `.env` out of version control (in `.gitignore`)
- Commit workflow JSON files
- Document any manual configuration steps

## Post-Deployment

After successful deployment:

1. **Run Initialization Job:**
   - Go to Databricks Jobs UI
   - Find **LMIP_Initialization**
   - Click "Run now"
   - This creates schemas and seeds metadata

2. **Configure Daily Ingestion:**
   - Find **LMIP_Daily_Ingestion**
   - Set schedule (e.g., daily at 6 AM UTC)
   - Enable the job

3. **Monitor:**
   - Check job run history
   - Query audit tables:
     ```sql
     SELECT * FROM audit.audit_pipeline_runs 
     ORDER BY start_time DESC LIMIT 10;
     ```

## Support

For issues or questions:
1. Check validation output: `python validate_deployment.py`
2. Review logs in deployment output
3. Check Databricks Jobs UI for job run failures
4. Verify Unity Catalog permissions

## Related Documentation

- [LMIP Project README](../README.md)
- [Ingestion Documentation](../notebooks/ingestion/README_INGESTION.md)
- [Bronze Layer Documentation](../notebooks/bronze/README_BRONZE.md)
- [Workflow Dependency Graph](../workflows/workflow_dependency_graph.md)
