# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# MAGIC %md
# MAGIC # Pipeline Audit Logger
# MAGIC
# MAGIC Logs pipeline execution to `workspace.audit.audit_pipeline_runs` using the common logging function.
# MAGIC
# MAGIC ## Parameters
# MAGIC - `pipeline_name`: Name of the pipeline (e.g., 'silver_processing')
# MAGIC - `run_id`: Databricks Run ID
# MAGIC - `status`: Pipeline status ('success', 'failed')
# MAGIC - `start_time`: Pipeline start timestamp (ISO format)
# MAGIC - `catalog`: Catalog name (default: workspace)
# MAGIC - `schema`: Schema name (default: audit)

# COMMAND ----------

# MAGIC %run ../common/common_logging

# COMMAND ----------

# DBTITLE 1,Create Widgets
# Create widgets
dbutils.widgets.text("pipeline_name", "", "Pipeline Name")
dbutils.widgets.text("run_id", "", "Run ID")
dbutils.widgets.text("status", "success", "Status")
dbutils.widgets.text("start_time", "", "Start Time")
dbutils.widgets.text("rows_read", "0", "Rows Read")
dbutils.widgets.text("rows_written", "0", "Rows Written")
dbutils.widgets.text("catalog", "workspace", "Catalog")
dbutils.widgets.text("schema", "audit", "Schema")

# COMMAND ----------

# DBTITLE 1,Get Widget Parameters
# Get widget parameters
pipeline_name = dbutils.widgets.get("pipeline_name")
run_id = dbutils.widgets.get("run_id")
status = dbutils.widgets.get("status").upper()  # Ensure uppercase
start_time_str = dbutils.widgets.get("start_time")
rows_read = int(dbutils.widgets.get("rows_read"))
rows_written = int(dbutils.widgets.get("rows_written"))
catalog = dbutils.widgets.get("catalog")
schema = dbutils.widgets.get("schema")

print(f"Pipeline: {pipeline_name}")
print(f"Run ID: {run_id}")
print(f"Status: {status}")
print(f"Rows Read: {rows_read:,}")
print(f"Rows Written: {rows_written:,}")

# COMMAND ----------

from datetime import datetime, timedelta

# Parse start time (ISO format or Unix timestamp in milliseconds)
if start_time_str:
    try:
        # Try parsing as ISO format first
        start_time = datetime.fromisoformat(start_time_str.replace('Z', '+00:00'))
    except:
        # Try parsing as Unix timestamp in milliseconds
        start_time = datetime.fromtimestamp(int(start_time_str) / 1000)
else:
    # Default to current time minus 1 second
    start_time = datetime.now() - timedelta(seconds=1)

end_time = datetime.now()

print(f"Start Time: {start_time}")
print(f"End Time: {end_time}")
print(f"Duration: {(end_time - start_time).total_seconds():.2f}s")

# COMMAND ----------

# DBTITLE 1,Log Audit Record
# Use common logging function to write audit record
log_audit_pipeline_run(
    pipeline_name=pipeline_name,
    run_id=run_id,
    status=status,
    start_time=start_time,
    end_time=end_time,
    rows_read=rows_read,
    rows_written=rows_written,
    error_message=None,
    catalog=catalog,
    schema=schema
)

print(f"✅ Audit record written to {catalog}.{schema}.audit_pipeline_runs")
print(f"   Pipeline: {pipeline_name}")
print(f"   Run ID: {run_id}")
print(f"   Status: {status}")
