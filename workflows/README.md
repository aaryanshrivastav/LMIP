# LMIP Workflows

This directory contains Databricks workflow definitions for the Labor Market Intelligence Platform (LMIP) data pipeline.

## Workflow Files

### LMIPDataIngestion

**Source Job ID**: `1013392226500135`  
**Schedule**: Hourly (every 1 hour)  
**Format**: Multi-task workflow

**Available Formats**:
* `LMIPDataIngestion.yml` - Human-readable YAML format (recommended for version control)
* `LMIPDataIngestion.json` - JSON format (API-compatible)

---

## Workflow Architecture

The LMIP Data Ingestion workflow follows a medallion architecture pattern for the Bronze layer:

```
┌─────────────────────────────────────────────────────────────┐
│                    PARALLEL INGESTION                       │
├─────────────────────────┬───────────────────────────────────┤
│   Arbeit_Ingestor       │      Remotive_Ingestor            │
│   (arbeitnow API)       │      (remotive API)               │
└───────────┬─────────────┴────────────┬──────────────────────┘
            │                          │
            └──────────┬───────────────┘
                       ▼
            ┌──────────────────────┐
            │      API_Log         │
            │  (response logging)  │
            └──────────┬───────────┘
                       ▼
            ┌──────────────────────┐
            │   Job_Snapshot       │
            │  (job metadata)      │
            └──────────┬───────────┘
                       ▼
            ┌──────────────────────┐
            │   Dedupe_Check       │
            │  (duplicate detect)  │
            └──────────┬───────────┘
                       ▼
            ┌──────────────────────┐
            │  Finalise_Batch      │
            │  (batch completion)  │
            └──────────────────────┘
```

---

## Task Details

### 1. Parallel Ingestion Tasks

**Arbeit_Ingestor** & **Remotive_Ingestor**
* Run in parallel (no dependencies between them)
* Fetch job postings from respective APIs
* Generate a single `batch_id` UUID per ingestion
* Write raw API responses to `workspace.bronze.bronze_job_snapshot`

### 2. API_Log
* **Depends on**: Both ingestion tasks
* Logs API request/response metadata for audit trail
* Writes to `workspace.bronze.bronze_api_response_log`
* Uses the same `batch_id` from ingestion

### 3. Job_Snapshot
* **Depends on**: API_Log
* Captures job execution metadata
* Writes to `workspace.bronze.bronze_job_snapshot`
* Tracks job configuration and runtime parameters

### 4. Dedupe_Check
* **Depends on**: Job_Snapshot
* Identifies duplicate payloads using `payload_hash`
* Writes deduplication tracking to `workspace.bronze.dedupe_tracking`
* Tracks `first_seen_batch_id` for lineage
* **Does not delete data** - maintains immutable Bronze principle

### 5. Finalise_Batch
* **Depends on**: Dedupe_Check
* Marks the batch as complete
* Writes batch metadata to `workspace.bronze.batch_metadata`
* Records counts, status, and timestamps

---

## Batch ID Consistency

**Critical Design Principle**: A single `batch_id` UUID flows through the entire pipeline.

```
Ingestion (ingest_common_helpers)
    ↓ generates ONE batch_id UUID
    ├→ bronze_job_snapshot (batch_id)
    ├→ bronze_api_response_log (batch_id)
    ↓
Deduplication (bronze_dedupe_raw_payload)
    ↓ REUSES ingestion batch_id
    ├→ dedupe_tracking (first_seen_batch_id = ingestion batch_id)
    ↓
Finalization (bronze_finalize_batch)
    ↓ REUSES ingestion batch_id
    └→ batch_metadata (batch_id = ingestion batch_id)
```

**Why This Matters**:
* Complete lineage traceability from ingestion → deduplication → finalization
* Enables downstream Silver/Gold layers to trace data origins
* Supports audit requirements and data quality investigations

---

## Configuration

### Trigger
* **Type**: Periodic
* **Interval**: 1 hour
* **Pause Status**: Unpaused (active)

### Concurrency
* **Max Concurrent Runs**: 1 (prevents overlapping executions)

### Performance
* **Target**: Performance Optimized
* **Queue**: Enabled (queues runs if previous run is still active)

### Environment
* **Version**: 5 (latest)
* **Compute**: Serverless (auto-scaling)

---

## Bronze Layer Tables

All tasks write to the `workspace.bronze` schema:

| Table | Purpose | Populated By |
|-------|---------|-------------|
| `bronze_job_snapshot` | Raw API response payloads | Ingestion tasks |
| `bronze_api_response_log` | API request/response metadata | API_Log task |
| `dedupe_tracking` | Duplicate detection records | Dedupe_Check task |
| `batch_metadata` | Batch completion records | Finalise_Batch task |

---

## Usage

### Viewing the Active Job
* Navigate to: [Jobs > LMIPDataIngestion](https://dbc-fe7d23c7-3321.cloud.databricks.com/jobs/1013392226500135)
* View run history, task execution times, and logs

### Modifying the Workflow
1. Edit the YAML or JSON file in this directory
2. Use the Databricks CLI to update the job:
   ```bash
   databricks jobs update --job-id 1013392226500135 --json-file LMIPDataIngestion.json
   ```

### Manual Execution
* Trigger via UI: Jobs page > "Run now" button
* Trigger via CLI:
   ```bash
   databricks jobs run-now --job-id 1013392226500135
   ```

---

## Monitoring & Troubleshooting

### Recent Run Performance
The workflow typically completes in **2-3 minutes**:
* Ingestion tasks: ~30-60 seconds each (parallel)
* Bronze processing: ~1-2 minutes total

### Common Issues

**Issue**: Batch ID inconsistency  
**Solution**: Verify that deduplication and finalization tasks are using `batch_id` from bronze_job_snapshot, not generating new UUIDs

**Issue**: Duplicate records not tracked  
**Solution**: Check that dedupe_tracking table has `first_seen_batch_id` column populated

**Issue**: Finalization fails with "source_name required"  
**Solution**: Ensure bronze_job_snapshot has `source_name` populated from ingestion tasks

---

## Version History

| Date | Change | Author |
|------|--------|--------|
| 2026-06-06 | Initial export to LMIP/workflows | System |
| 2026-06-06 | Fixed batch_id consistency across Bronze notebooks | System |

---

## Next Steps

* [ ] Add Silver layer processing tasks
* [ ] Implement Gold layer aggregation tasks
* [ ] Add data quality checks between layers
* [ ] Configure email/Slack notifications for failures
* [ ] Set up automated testing for workflow changes