"""
LMIP Bronze Batch Rollback
===========================

Rollback a specific bronze batch by:
1. Marking the batch as ROLLED_BACK in bronze.dedupe_tracking
2. Soft-deleting affected rows in silver_jobs_current
3. Writing an audit record to audit.audit_pipeline_runs

This is the cleanest rollback mechanism - only the batch_status flag is toggled.

Usage:
    Run as a notebook with widgets:
    - batch_id: The batch ID to rollback
    - catalog: Unity Catalog (default: workspace)
    - reason: Reason for rollback (for audit trail)
    - dry_run: If true, shows what would be rolled back without making changes
"""

# Databricks notebook source
# MAGIC %md
# MAGIC # Bronze Batch Rollback
# MAGIC 
# MAGIC Rollback mechanism for bronze batches:
# MAGIC * Marks batch as `ROLLED_BACK` in dedupe tracking
# MAGIC * Soft-deletes affected rows in silver_jobs_current
# MAGIC * Writes audit record
# MAGIC 
# MAGIC **WARNING**: This operation affects downstream silver and gold layers!

# COMMAND ----------

# Import required libraries
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import col, current_timestamp, lit
from datetime import datetime, timezone
import json

# COMMAND ----------

# Widget parameters
dbutils.widgets.text("batch_id", "", "Batch ID to Rollback")
dbutils.widgets.text("catalog", "workspace", "Unity Catalog")
dbutils.widgets.text("reason", "Data quality issue", "Rollback Reason")
dbutils.widgets.dropdown("dry_run", "true", ["true", "false"], "Dry Run Mode")

# Get parameters
batch_id = dbutils.widgets.get("batch_id")
catalog = dbutils.widgets.get("catalog")
reason = dbutils.widgets.get("reason")
dry_run = dbutils.widgets.get("dry_run").lower() == "true"

# Validate required parameters
if not batch_id:
    raise ValueError("batch_id parameter is required")

print(f"""
╔══════════════════════════════════════════════════════════╗
║         Bronze Batch Rollback                            ║
╚══════════════════════════════════════════════════════════╝

Batch ID:    {batch_id}
Catalog:     {catalog}
Reason:      {reason}
Dry Run:     {dry_run}
Timestamp:   {datetime.now(timezone.utc).isoformat()}

""")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 1: Verify Batch Exists and Get Metadata

# COMMAND ----------

# Check if batch exists in dedupe_tracking
dedupe_tracking_table = f"{catalog}.bronze.dedupe_tracking"
silver_current_table = f"{catalog}.silver.silver_jobs_current"
audit_table = f"{catalog}.audit.audit_pipeline_runs"

# Query batch metadata
batch_metadata_df = spark.sql(f"""
SELECT 
    batch_id,
    source_table,
    batch_status,
    COUNT(*) as record_count,
    MIN(first_seen_timestamp) as earliest_record,
    MAX(last_seen_timestamp) as latest_record
FROM {dedupe_tracking_table}
WHERE batch_id = '{batch_id}'
GROUP BY batch_id, source_table, batch_status
""")

if batch_metadata_df.count() == 0:
    raise ValueError(f"Batch {batch_id} not found in {dedupe_tracking_table}")

# Get current batch status
batch_info = batch_metadata_df.first()
current_status = batch_info.batch_status
record_count = batch_info.record_count

print(f"""
Batch Metadata:
  Batch ID:        {batch_id}
  Source Table:    {batch_info.source_table}
  Current Status:  {current_status}
  Record Count:    {record_count}
  Earliest Record: {batch_info.earliest_record}
  Latest Record:   {batch_info.latest_record}
""")

# Check if batch is already rolled back
if current_status == "ROLLED_BACK":
    print("⚠️  WARNING: Batch is already in ROLLED_BACK status")
    if not dry_run:
        print("Exiting - no action needed")
        dbutils.notebook.exit(json.dumps({
            "status": "skipped",
            "message": "Batch already rolled back",
            "batch_id": batch_id
        }))

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 2: Identify Affected Silver Records

# COMMAND ----------

# Find affected records in silver_jobs_current
# These are records that originated from this batch
affected_silver_query = f"""
SELECT 
    job_id,
    source_job_id,
    source_name,
    batch_id,
    is_deleted,
    created_at,
    updated_at
FROM {silver_current_table}
WHERE batch_id = '{batch_id}'
"""

affected_silver_df = spark.sql(affected_silver_query)
affected_silver_count = affected_silver_df.count()

print(f"""
Affected Silver Records:
  Total Records: {affected_silver_count}
""")

if affected_silver_count > 0:
    # Show sample of affected records
    print("\nSample of affected records (first 10):")
    affected_silver_df.select(
        "job_id", "source_job_id", "source_name", "is_deleted"
    ).show(10, truncate=False)
else:
    print("⚠️  No affected records found in silver_jobs_current")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 3: Execute Rollback (or Dry Run)

# COMMAND ----------

if dry_run:
    print("=" * 60)
    print("DRY RUN MODE - No changes will be made")
    print("=" * 60)
    print(f"\nWould rollback batch {batch_id}:")
    print(f"  • Mark {record_count} records as ROLLED_BACK in dedupe_tracking")
    print(f"  • Soft-delete {affected_silver_count} records in silver_jobs_current")
    print(f"  • Write audit record to {audit_table}")
    print("\nTo execute rollback, set dry_run=false")
    
else:
    print("=" * 60)
    print("EXECUTING ROLLBACK")
    print("=" * 60)
    
    rollback_start = datetime.now(timezone.utc)
    
    # Step 3a: Update dedupe_tracking batch_status
    print(f"\n1. Updating {dedupe_tracking_table}...")
    update_dedupe_sql = f"""
    UPDATE {dedupe_tracking_table}
    SET 
        batch_status = 'ROLLED_BACK',
        tracking_timestamp = current_timestamp()
    WHERE batch_id = '{batch_id}'
    """
    spark.sql(update_dedupe_sql)
    print(f"   ✓ Marked {record_count} records as ROLLED_BACK")
    
    # Step 3b: Soft-delete affected silver records
    if affected_silver_count > 0:
        print(f"\n2. Soft-deleting records in {silver_current_table}...")
        update_silver_sql = f"""
        UPDATE {silver_current_table}
        SET 
            is_deleted = true,
            updated_at = current_timestamp()
        WHERE batch_id = '{batch_id}'
        """
        spark.sql(update_silver_sql)
        print(f"   ✓ Soft-deleted {affected_silver_count} records")
    else:
        print(f"\n2. No silver records to soft-delete")
    
    rollback_end = datetime.now(timezone.utc)
    rollback_duration = (rollback_end - rollback_start).total_seconds()
    
    # Step 3c: Write audit record
    print(f"\n3. Writing audit record to {audit_table}...")
    
    audit_record = spark.createDataFrame([{
        "pipeline_name": "bronze_rollback_batch",
        "run_id": dbutils.notebook.entry_point.getDbutils().notebook().getContext().currentRunId().get(),
        "status": "SUCCESS",
        "start_time": rollback_start,
        "end_time": rollback_end,
        "duration_seconds": rollback_duration,
        "rows_read": record_count,
        "rows_written": affected_silver_count,
        "error_message": None,
        "metadata": json.dumps({
            "batch_id": batch_id,
            "rollback_reason": reason,
            "dedupe_records_marked": record_count,
            "silver_records_deleted": affected_silver_count,
            "source_table": batch_info.source_table
        }),
        "created_at": rollback_end
    }])
    
    audit_record.write.mode("append").saveAsTable(audit_table)
    print(f"   ✓ Audit record written")
    
    print("\n" + "=" * 60)
    print("ROLLBACK COMPLETE")
    print("=" * 60)
    print(f"""
Summary:
  Batch ID:              {batch_id}
  Records Rolled Back:   {record_count}
  Silver Records Deleted: {affected_silver_count}
  Duration:              {rollback_duration:.2f} seconds
  Reason:                {reason}
""")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Step 4: Return Results

# COMMAND ----------

# Return results as JSON for workflow orchestration
result = {
    "status": "success" if not dry_run else "dry_run",
    "batch_id": batch_id,
    "dedupe_records_marked": record_count if not dry_run else 0,
    "silver_records_deleted": affected_silver_count if not dry_run else 0,
    "reason": reason,
    "dry_run": dry_run,
    "timestamp": datetime.now(timezone.utc).isoformat()
}

print(f"\nResult: {json.dumps(result, indent=2)}")

dbutils.notebook.exit(json.dumps(result))
