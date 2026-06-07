# LMIP Data Publishing System

Complete data publishing infrastructure for LMIP (Labor Market Information Platform).

## Overview

This directory contains all artifacts necessary to publish LMIP data from Databricks Warehouse/Gold layers to:

* **Supabase** (Primary consumer database)
* **CSV Bundles** (Portable archives)
* **Consumer Deployments** (Self-contained installations)

## Key Principles

**Reproducibility:** Consumers can deploy data without Databricks access  
**Versioning:** Semantic versioning (YYYY.WW.PATCH) with full history  
**Recovery:** Multiple backup strategies and rollback procedures  
**Quality:** Automated validation gates before and after publication

## Directory Structure

```
lmip_publish/
├── README.md (this file)
├── publish_contracts.md (comprehensive specification)
├── scripts/
│   ├── export_bundle.py (Databricks: export to CSV)
│   ├── load_bundle.py (Consumer: import from CSV)
│   ├── load_dimensions.sql (Consumer: create dimension tables)
│   ├── load_facts.sql (Consumer: create fact tables)
│   └── validate_import.sql (Consumer: validate data quality)
└── export_bundle_notebook.ipynb (Databricks notebook version)
```

## Quick Start

### Producer Side (Databricks)

**Export Full Bundle:**

```bash
python scripts/export_bundle.py \
  --catalog workspace \
  --warehouse-schema warehouse \
  --gold-schema gold \
  --output /dbfs/mnt/lmip-exports \
  --mode full
```

**Export Incremental:**

```bash
python scripts/export_bundle.py \
  --catalog workspace \
  --warehouse-schema warehouse \
  --gold-schema gold \
  --output /dbfs/mnt/lmip-exports \
  --mode incremental \
  --from-date 20260601
```

### Consumer Side (PostgreSQL/Supabase)

**1. Download Bundle:**

```bash
wget https://lmip.publishing/exports/lmip_export_20260607_120000.tar.gz
tar -xzf lmip_export_20260607_120000.tar.gz
cd lmip_export_20260607_120000
```

**2. Validate Bundle:**

```bash
python scripts/load_bundle.py --validate-only --manifest manifest.json
```

**3. Create Schema (first time only):**

```bash
psql $DATABASE_URL -f scripts/load_dimensions.sql
psql $DATABASE_URL -f scripts/load_facts.sql
```

**4. Load Data:**

```bash
# Full refresh
python scripts/load_bundle.py \
  --database-url $DATABASE_URL \
  --manifest manifest.json \
  --mode full

# Incremental update
python scripts/load_bundle.py \
  --database-url $DATABASE_URL \
  --manifest manifest.json \
  --mode incremental
```

**5. Validate Import:**

```bash
psql $DATABASE_URL -f scripts/validate_import.sql
```

## Data Architecture

### Warehouse Layer (6 Dimension Tables)

* **dim_sector** - Industry sectors (Technology, Hospitality, etc.)
* **dim_company** - Companies and employers
* **dim_location** - Geographic locations (city, state, country)
* **dim_role** - Job roles and titles
* **dim_skill** - Skills and competencies
* **dim_source** - Data sources and endpoints

### Gold Layer (5 Fact Tables)

* **gold_company_hiring** - Company hiring activity trends
* **gold_hospitality_companies** - Hospitality sector-specific metrics
* **gold_salary_trends** - Salary analytics by role/location
* **gold_skill_demand** - Skill demand and mentions
* **gold_location_trends** - Geographic job market trends

## Export Order

Tables are exported in dependency order to maintain referential integrity:

**Phase 1: Dimensions** (no dependencies, can export in parallel)
1. dim_sector
2. dim_source
3. dim_company
4. dim_location
5. dim_role
6. dim_skill

**Phase 2: Facts** (depend on dimensions, must wait for Phase 1)
7. gold_company_hiring
8. gold_hospitality_companies
9. gold_location_trends
10. gold_salary_trends
11. gold_skill_demand

## Versioning

**Format:** `YYYY.WW.PATCH`

* **YYYY** - 4-digit year
* **WW** - ISO week number (01-53)
* **PATCH** - Incremental republish counter within the same week

**Examples:**
* `2026.23.0` - First publication of week 23, 2026
* `2026.23.1` - Second publication (correction)
* `2026.24.0` - First publication of week 24

## Manifest Schema

Every bundle includes a `manifest.json` with:

* **Publication metadata** - Bundle ID, version, timestamp, publisher
* **Data period** - Start/end dates, granularity, incremental flag
* **Table inventory** - File names, row counts, checksums, schemas
* **Statistics** - Total rows, size, table counts
* **Quality checks** - Referential integrity, NULL checks, variance
* **Compatibility** - Min consumer version, breaking changes

See `publish_contracts.md` Section 3 for full schema.

## Incremental Publishing

**Daily Incremental:** Monday-Saturday, 02:00 UTC  
**Weekly Full Refresh:** Sunday, 04:00 UTC  
**Monthly Full Archive:** First Sunday, 06:00 UTC

**Incremental Strategy:**
* Dimensions: UPSERT based on surrogate keys
* Facts: INSERT only new date ranges (no duplicates)
* Consumer merges incrementally without full reloads

See `publish_contracts.md` Section 6 for details.

## Recovery Procedures

**Scenario A: Failed Export**
* Impact: No consumer impact
* Action: Automatic retry (3 attempts)

**Scenario B: Corrupted Bundle**
* Impact: Consumers may download bad data
* Action: Deprecate version, publish rollback manifest

**Scenario C: Bad Data Published**
* Impact: Incorrect analytics downstream
* Action: Deprecate, issue rollback advisory, re-export corrected data

**Scenario D: Complete Data Loss**
* Impact: Cannot generate new exports
* Action: Restore from Delta Lake time travel or published bundle backups

See `publish_contracts.md` Section 7 for full procedures.

## Quality Gates

**Pre-Publication Checks:**
* Row count sanity (within 10-20% variance)
* Referential integrity (all FKs exist)
* NULL constraints (no NULLs in required columns)
* Date range validity (YYYYMMDD format)
* Checksum validation

**Post-Publication Monitoring:**
* Consumer download success rates
* Load times and errors
* Data freshness alerts
* Query performance

## Scripts Reference

### `export_bundle.py`

**Purpose:** Export Databricks tables to CSV bundle  
**Runtime:** Databricks with PySpark  
**Key Features:**
* Dependency-aware export order
* Checksum calculation
* Manifest generation
* Incremental date filtering

### `load_bundle.py`

**Purpose:** Load CSV bundle into PostgreSQL/Supabase  
**Runtime:** Any Python 3.9+ environment  
**Dependencies:** `pandas`, `psycopg2`, `jsonschema`  
**Key Features:**
* Bundle validation (checksums, row counts)
* Full refresh mode (truncate + reload)
* Incremental mode (upsert dimensions, append facts)
* Transaction safety (rollback on error)

### `load_dimensions.sql`

**Purpose:** Create dimension table schemas  
**Runtime:** PostgreSQL/Supabase  
**Creates:**
* All 6 dimension tables with PKs, indexes, comments
* Unique constraints on natural keys

### `load_facts.sql`

**Purpose:** Create fact table schemas  
**Runtime:** PostgreSQL/Supabase  
**Creates:**
* All 5 fact tables with PKs, FKs, indexes
* `version_history` tracking table

### `validate_import.sql`

**Purpose:** Validate imported data quality  
**Runtime:** PostgreSQL/Supabase  
**Checks:**
* Row counts
* Referential integrity
* NULL constraints
* Date ranges
* Duplicate keys
* Negative counts

## Environment Variables

**Consumer Side:**

```bash
export DATABASE_URL="postgresql://user:pass@host:5432/dbname"
# or for Supabase:
export DATABASE_URL="postgresql://postgres:[YOUR-PASSWORD]@db.[YOUR-PROJECT].supabase.co:5432/postgres"
```

**Producer Side (Databricks):**

No environment variables required. Uses Spark session context.

## Scheduling

**Recommended Databricks Job Schedule:**

```yaml
trigger:
  schedule:
    quartz_cron_expression: "0 0 2 ? * MON-SAT"
    timezone_id: "UTC"
  
tasks:
  - task_key: export_incremental
    python_wheel_task:
      package_name: lmip_publishing
      entry_point: export_bundle
      parameters:
        - "--mode"
        - "incremental"
        - "--output"
        - "/dbfs/mnt/lmip-exports"

# Separate job for full refresh on Sundays
trigger:
  schedule:
    quartz_cron_expression: "0 0 4 ? * SUN"
    timezone_id: "UTC"
  
tasks:
  - task_key: export_full
    python_wheel_task:
      package_name: lmip_publishing
      entry_point: export_bundle
      parameters:
        - "--mode"
        - "full"
        - "--output"
        - "/dbfs/mnt/lmip-exports"
```

## Monitoring

**Key Metrics:**
* Export duration (baseline: ~15 minutes)
* Bundle size (baseline: ~50 MB)
* Row count variance (alert if > 10%)
* Consumer download rate
* Import success rate

**Alert Channels:**
* PagerDuty - Critical failures
* Slack #data-engineering - Warnings
* Status page - Consumer-facing issues

## Support

**Documentation:** See `publish_contracts.md` for comprehensive specification  
**Issues:** GitHub repository (TBD)  
**Contact:** data-engineering@lmip.org

## Version History

**v1.0.0** (2026-06-07)
* Initial publishing infrastructure
* Full and incremental export modes
* Supabase and CSV bundle targets
* Validation and recovery procedures

---

**Note:** This publishing system ensures LMIP data is **reproducible, versioned, and recoverable** for all consumers without requiring Databricks access.
