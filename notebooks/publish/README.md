# LMIP Publication System

## Overview

The LMIP Publication System implements a deterministic, manifest-driven data publication pipeline for serving-layer distribution. It exports Unity Catalog Gold and Audit tables to multiple consumer formats with comprehensive validation, checksums, and load order management.

## Architecture

### Publication Targets

1. **CSV Snapshot Bundles** - Compressed, versioned exports for offline/bootstrap consumption
2. **Supabase Postgres** - Real-time query interface for consumer applications
3. **Manifest Files** - Machine-readable metadata for automated loading

### Design Principles

* **Deterministic**: Sorted exports ensure reproducible results
* **Manifest-Driven**: All operations guided by explicit manifests
* **Validated**: Multiple validation layers at each stage
* **Versioned**: Timestamped snapshots with rollback support
* **Auditable**: Complete logging of all operations

## Quick Start

### Run the Full Pipeline

```python
# Open and run: 00_publish_orchestrator.ipynb
EXECUTION_MODE = "full"
```

This will:
1. Export all tables to CSV snapshots
2. Generate manifest files
3. Validate the snapshot
4. Sync to Supabase Postgres

## Notebooks

### 00_publish_orchestrator
Master orchestration - runs all stages in sequence.

### publish_csv_snapshot_export
Export tables to compressed CSV files with checksums.

### publish_manifest_write
Generate schema, compatibility, and load order manifests.

### publish_load_order_check
Validate snapshot integrity and bootstrap readiness.

### publish_supabase_upsert
Sync data to Supabase Postgres with conflict resolution.

## Table Load Order

```
Phase 1: Dimensions
  → dim_date, dim_sector, dim_role, dim_location, dim_company

Phase 2: Facts
  → fact_job_postings (depends on all dimensions)

Phase 3: Gold Marts
  → gold_hiring_trends, gold_sector_metrics, gold_location_heatmap

Phase 4: Audit
  → audit_data_quality_log, audit_pipeline_runs, audit_source_freshness
```

## Output Structure

```
/Volumes/workspace/publish/snapshots/2026-06-04_143022/
├── data/
│   ├── dim_date.csv.gz
│   ├── dim_sector.csv.gz
│   └── ...
├── checksums.json
├── metadata.json
├── snapshot_manifest.json
├── schema_manifest.json
├── compatibility.json
├── load_order.json
└── validation_report.json
```

## Monitoring

### Check Pipeline Status
```sql
SELECT execution_mode, overall_status, duration_sec/60 as duration_min
FROM workspace.audit.publish_pipeline_log
ORDER BY started_at DESC LIMIT 10;
```

### Check Validation Issues
```sql
SELECT snapshot_id, overall_status, checks_failed, total_issues
FROM workspace.audit.publish_validation_log
WHERE overall_status = 'FAIL'
ORDER BY validated_at DESC;
```

## Consumer Usage

### Load from CSV Snapshots
```python
import pandas as pd
import gzip
import json

# Read manifest
with open('snapshot_manifest.json') as f:
    manifest = json.load(f)

# Load tables in dependency order
for item in manifest['load_order']:
    with gzip.open(item['file'], 'rt') as f:
        df = pd.read_csv(f)
    # Load to your target database
```

### Query Supabase
```python
import psycopg2

conn = psycopg2.connect(
    host="your-project.supabase.co",
    database="postgres",
    user="postgres",
    password="your-password"
)

cursor = conn.cursor()
cursor.execute("SELECT * FROM gold_hiring_trends LIMIT 10")
results = cursor.fetchall()
```

## Configuration

### Supabase Credentials
Store in Databricks Secrets:
```python
dbutils.secrets.put(scope="supabase", key="host", string_value="...")
dbutils.secrets.put(scope="supabase", key="port", string_value="5432")
dbutils.secrets.put(scope="supabase", key="database", string_value="postgres")
dbutils.secrets.put(scope="supabase", key="username", string_value="postgres")
dbutils.secrets.put(scope="supabase", key="password", string_value="...")
```

## Troubleshooting

**Checksum Mismatch**: Re-run export, verify file integrity

**Row Count Mismatch**: Data changed between export and validation - run pipeline end-to-end

**Circular Dependencies**: Review TABLE_DEFINITIONS in manifest_write notebook

**Supabase Timeout**: Increase timeout, reduce batch size, check credentials

## Version History

v1.0 (2026-06-04)
* Initial release with full pipeline
* CSV export, manifest generation, validation, Supabase sync
* Orchestration framework
