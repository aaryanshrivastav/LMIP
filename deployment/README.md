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
- Unity Catalog schemas (bronze, silver, intermediate, gold, reporting, metadata, audit)
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
INTERMEDIATE_SCHEMA=intermediate
GOLD_SCHEMA=gold
REPORTING_SCHEMA=reporting
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
