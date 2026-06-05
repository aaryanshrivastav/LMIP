# LMIP Initialization Notebooks

**Purpose**: Environment bootstrap and schema initialization for the Labour Market Intelligence Platform (LMIP)

**Location**: `/LMIP/notebooks/init/`

---

## Overview

This directory contains initialization notebooks for first-run setup of LMIP in both self-hosted and consumer deployment scenarios. These notebooks are **idempotent** and safe to run multiple times.

---

## Notebooks

### 1. init_create_schemas

**Purpose**: Create all required schemas for the LMIP platform

**Target**: `workspace` catalog

**Schemas Created**:
* `metadata` - Source configurations, DQ rules, taxonomy, run control
* `bronze` - Raw ingestion layer (API snapshots, response logs)
* `silver` - Cleansed and deduplicated jobs data
* `semantic` - Enriched semantic layer (role mapping, skills, company canonical)
* `warehouse` - Star schema dimensional model (dims + facts)
* `gold` - Pre-aggregated business metrics and trends
* `audit` - Pipeline runs, DQ results, access events
* `publish` - Consumer-ready datasets and reports
* `quarantine` - Failed records and data quality violations

**Usage**:
```python
dbutils.notebook.run("/LMIP/notebooks/init/init_create_schemas", timeout_seconds=300)
```

**Returns**: `SUCCESS` or `FAILED`

---

### 2. init_seed_metadata

**Purpose**: Seed initial metadata tables with source configurations, DQ rules, and taxonomy mappings

**Target**: `workspace.metadata` schema

**Tables Seeded**:
* `source_config` - External API source configurations (Remotive, Arbeitnow)
* `dq_rule_definitions` - Data quality rule definitions and thresholds
* `taxonomy_role_canonical` - Canonical role taxonomy for job title mapping
* `taxonomy_skill_catalog` - Master skill catalog with categorization

**Usage**:
```python
dbutils.notebook.run("/LMIP/notebooks/init/init_seed_metadata", timeout_seconds=600)
```

**Returns**: `SUCCESS` or `PARTIAL`

**Features**:
* Uses MERGE to upsert seed data (idempotent)
* Includes 19 canonical roles and 25+ skills
* 5 baseline DQ rules for data validation

---

### 3. init_validate_env

**Purpose**: Validate runtime environment and dependencies

**Validation Checks**:
1. **Python Environment** - Version and required packages
2. **Spark Environment** - Version, configuration, cluster responsiveness
3. **Catalog and Schemas** - Existence validation
4. **Key Tables** - Accessibility checks
5. **Network Connectivity** - API endpoint reachability
6. **Permissions** - CREATE TABLE and INSERT permissions

**Usage**:
```python
result = dbutils.notebook.run("/LMIP/notebooks/init/init_validate_env", timeout_seconds=300)
if result != "SUCCESS":
    raise Exception("Environment validation failed")
```

**Returns**: `SUCCESS`, `WARNINGS`, or `FAILED`

---

### 4. init_register_secrets

**Purpose**: Register and validate Databricks Secrets for LMIP platform

**Secret Scopes**:
* `lmip-api` - API keys and credentials for external data sources
* `lmip-notifications` - Email/Slack/webhook credentials for alerts
* `lmip-superset` - Superset database connection strings

**Usage**:
```python
result = dbutils.notebook.run("/LMIP/notebooks/init/init_register_secrets", timeout_seconds=300)
if result != "SUCCESS":
    print("Some secrets are missing - see validation report")
```

**Returns**: `SUCCESS` or `INCOMPLETE`

**Setup Steps**:

1. **Create Secret Scopes**:
   ```bash
   databricks secrets create-scope --scope lmip-api
   databricks secrets create-scope --scope lmip-notifications
   databricks secrets create-scope --scope lmip-superset
   ```

2. **Add Secrets**:
   ```bash
   # Notification credentials
   databricks secrets put --scope lmip-notifications --key email-smtp-server
   databricks secrets put --scope lmip-notifications --key email-smtp-port
   databricks secrets put --scope lmip-notifications --key email-username
   databricks secrets put --scope lmip-notifications --key email-password
   databricks secrets put --scope lmip-notifications --key slack-webhook-url
   
   # Superset credentials
   databricks secrets put --scope lmip-superset --key superset-db-connection-string
   databricks secrets put --scope lmip-superset --key superset-api-token
   ```

---

### 5. init_superset_bootstrap

**Purpose**: Bootstrap Superset connectivity and initial dataset registration for consumer-mode dashboards

**Operations**:
* Validate Superset connection credentials
* Validate publish schema and datasets
* Generate Superset dataset configuration
* Export configuration for manual setup
* Provide setup instructions

**Usage**:
```python
result = dbutils.notebook.run(
    "/LMIP/notebooks/init/init_superset_bootstrap",
    timeout_seconds=600
)
if result == "SUCCESS":
    print("Superset bootstrapped successfully")
```

**Returns**: `SUCCESS`, `PARTIAL`, `DATASETS_PENDING`, or `CREDENTIALS_MISSING`

**Datasets Registered**:
* `publish.pub_job_listings` - Current job listings with enriched metadata
* `publish.pub_job_trends_daily` - Daily job posting trends and metrics
* `publish.pub_skills_demand` - Skills demand analysis and rankings
* `publish.pub_company_insights` - Company hiring patterns and insights
* `gold.gold_job_kpis_daily` - Daily KPIs and aggregated metrics

---

## Complete Initialization Workflow

### First-Time Setup

Run notebooks in this order:

```python
from datetime import datetime

print("LMIP Initialization Starting...")
print(f"Started: {datetime.now()}\n")

# Step 1: Create Schemas
print("[1/5] Creating schemas...")
result = dbutils.notebook.run("/LMIP/notebooks/init/init_create_schemas", timeout_seconds=300)
print(f"Result: {result}\n")

if result != "SUCCESS":
    raise Exception("Schema creation failed")

# Step 2: Seed Metadata
print("[2/5] Seeding metadata...")
result = dbutils.notebook.run("/LMIP/notebooks/init/init_seed_metadata", timeout_seconds=600)
print(f"Result: {result}\n")

# Step 3: Validate Environment
print("[3/5] Validating environment...")
result = dbutils.notebook.run("/LMIP/notebooks/init/init_validate_env", timeout_seconds=300)
print(f"Result: {result}\n")

if result == "FAILED":
    raise Exception("Environment validation failed")

# Step 4: Register Secrets (manual setup required first)
print("[4/5] Validating secrets...")
result = dbutils.notebook.run("/LMIP/notebooks/init/init_register_secrets", timeout_seconds=300)
print(f"Result: {result}\n")

if result == "INCOMPLETE":
    print("⚠ Secrets not fully configured - see notebook output for setup commands")
    print("Continue with Superset bootstrap...\n")

# Step 5: Bootstrap Superset (optional, for consumer mode)
print("[5/5] Bootstrapping Superset...")
result = dbutils.notebook.run("/LMIP/notebooks/init/init_superset_bootstrap", timeout_seconds=600)
print(f"Result: {result}\n")

print("✓ LMIP Initialization Complete!")
print(f"Finished: {datetime.now()}")
```

### Re-initialization (Safe to Run Anytime)

All notebooks are idempotent and can be re-run:

```python
# Re-create schemas (no-op if exist)
dbutils.notebook.run("/LMIP/notebooks/init/init_create_schemas", 300)

# Re-seed metadata (uses MERGE to upsert)
dbutils.notebook.run("/LMIP/notebooks/init/init_seed_metadata", 600)

# Re-validate environment
dbutils.notebook.run("/LMIP/notebooks/init/init_validate_env", 300)
```

---

## Deployment Scenarios

### Self-Hosted Deployment

Full initialization including all notebooks:
1. Run all 5 notebooks in order
2. Configure secrets for notifications and Superset
3. Set up Superset manually using bootstrap configuration
4. Run data pipelines to populate tables

### Consumer Mode Deployment

Minimal initialization for read-only access:
1. Run `init_create_schemas` (only if managing your own catalog)
2. Run `init_validate_env` to verify connectivity
3. Run `init_superset_bootstrap` to configure consumer dashboards
4. Skip `init_seed_metadata` and `init_register_secrets` (managed by provider)

---

## Integration with Existing Notebooks

The init notebooks **replace** the following legacy bootstrap code:

| Legacy Location | Replaced By | Action Needed |
|----------------|-------------|---------------|
| `LMIP/notebooks/schema_creation` | `init_create_schemas` | Update references to use init notebook |
| Inline metadata seeding in ingestion notebooks | `init_seed_metadata` | Remove inline seed code, call init notebook instead |
| Ad-hoc environment checks | `init_validate_env` | Standardize on init notebook |

**Migration**: Update any workflows or orchestration that reference `schema_creation` to use `init_create_schemas` instead.

---

## Troubleshooting

### Schema Creation Issues

**Problem**: Schema creation fails with permission error

**Solution**:
```sql
-- Grant catalog permissions
GRANT USE CATALOG ON CATALOG workspace TO `your-user-or-group`;
GRANT CREATE SCHEMA ON CATALOG workspace TO `your-user-or-group`;
```

### Metadata Seeding Issues

**Problem**: Merge fails with "table not found"

**Solution**: Run `init_create_schemas` first, then create tables using the main `schema_creation` notebook before seeding.

### Validation Warnings

**Problem**: `init_validate_env` returns WARNINGS

**Solution**: Review output to determine if warnings are acceptable for your environment (e.g., missing optional packages, table not created yet).

### Secret Configuration Issues

**Problem**: `init_register_secrets` returns INCOMPLETE

**Solution**: Follow the generated setup script in the notebook output to create missing secrets.

### Superset Bootstrap Issues

**Problem**: Datasets not found

**Solution**: Run data pipelines to populate `publish` and `gold` schemas first, then re-run `init_superset_bootstrap`.

---

## Maintenance

### Adding New Data Sources

1. Update `init_seed_metadata` to include new source configuration
2. Add corresponding API credentials to secrets
3. Re-run `init_seed_metadata` to add new source

### Adding New DQ Rules

1. Edit `init_seed_metadata` to include new rule definitions
2. Re-run to merge new rules into `metadata.dq_rule_definitions`

### Adding New Roles or Skills

1. Edit `init_seed_metadata` taxonomy data
2. Re-run to merge new taxonomy entries

---

## Related Documentation

* **Schema Architecture**: See `/LMIP/docs/architecture/schemas.md`
* **Data Quality Rules**: See `/LMIP/docs/quality/dq_rules.md`
* **Deployment Guide**: See `/LMIP/docs/deployment/setup.md`
* **Superset Integration**: See `/LMIP/docs/consumer/superset_setup.md`

---

## Change Log

**2026-06-05**
* Initial creation of init notebook suite
* Consolidated initialization logic from legacy notebooks
* Added comprehensive environment validation
* Added Superset bootstrap for consumer mode

---

**Questions or Issues?**

Contact the LMIP platform team or create an issue in the project repository.