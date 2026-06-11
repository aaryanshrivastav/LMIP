# Databricks notebook source
# DBTITLE 1,Audit Report Generator
# MAGIC %md
# MAGIC # Audit Report Generator
# MAGIC
# MAGIC **Purpose:** Generate comprehensive audit reports for recovery operations and pipeline validation.
# MAGIC
# MAGIC **Target Audience:** Data engineering, operations, and compliance teams
# MAGIC
# MAGIC **Report Types:**
# MAGIC * `recovery` - Post-recovery validation report with metrics
# MAGIC * `daily` - Daily pipeline execution summary
# MAGIC * `compliance` - Compliance and data quality report
# MAGIC
# MAGIC **Usage:**
# MAGIC ```python
# MAGIC dbutils.notebook.run(
# MAGIC     "LMIP/notebooks/audit/audit_generate_report",
# MAGIC     timeout_seconds=1800,
# MAGIC     arguments={
# MAGIC         "report_type": "recovery",
# MAGIC         "include_metrics": "true"
# MAGIC     }
# MAGIC )
# MAGIC ```

# COMMAND ----------

# DBTITLE 1,Import Common Utilities
# MAGIC %run ../common/common_logging

# COMMAND ----------

# DBTITLE 1,Import Libraries
from pyspark.sql import functions as F
from datetime import datetime, timezone, timedelta
import json

# COMMAND ----------

# DBTITLE 1,Notebook Parameters
# Initialize logger
logger = get_logger(__name__)

# Notebook parameters
dbutils.widgets.dropdown("report_type", "recovery", ["recovery", "daily", "compliance"], "Report Type")
dbutils.widgets.dropdown("include_metrics", "true", ["true", "false"], "Include Detailed Metrics")
dbutils.widgets.text("lookback_hours", "24", "Lookback Period (hours)")
dbutils.widgets.text("output_format", "markdown", "Output Format (markdown/json)")

# Retrieve parameters
report_type = dbutils.widgets.get("report_type")
include_metrics = dbutils.widgets.get("include_metrics").lower() == "true"
lookback_hours = int(dbutils.widgets.get("lookback_hours") or 24)
output_format = dbutils.widgets.get("output_format")

logger.info(f"Generating {report_type} report (lookback: {lookback_hours}h)")

# COMMAND ----------

# DBTITLE 1,Validate Parameters
# Validation
if report_type not in ["recovery", "daily", "compliance"]:
    raise ValueError(f"Invalid report_type: {report_type}. Must be 'recovery', 'daily', or 'compliance'")

if output_format not in ["markdown", "json"]:
    raise ValueError(f"Invalid output_format: {output_format}. Must be 'markdown' or 'json'")

logger.info("✓ Parameter validation passed")

# COMMAND ----------

# DBTITLE 1,Query Pipeline Run Metrics
# MAGIC %sql
# MAGIC -- Query recent pipeline runs for report
# MAGIC CREATE OR REPLACE TEMPORARY VIEW recent_pipeline_runs AS
# MAGIC SELECT 
# MAGIC     pipeline_name,
# MAGIC     environment,
# MAGIC     status,
# MAGIC     COUNT(*) as run_count,
# MAGIC     SUM(rows_read) as total_rows_read,
# MAGIC     SUM(rows_written) as total_rows_written,
# MAGIC     AVG(runtime_seconds) as avg_runtime_seconds,
# MAGIC     MAX(end_time) as last_run_time,
# MAGIC     SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END) as failed_count,
# MAGIC     SUM(CASE WHEN status = 'SUCCESS' THEN 1 ELSE 0 END) as success_count
# MAGIC FROM workspace.audit.audit_pipeline_runs
# MAGIC WHERE start_time >= CURRENT_TIMESTAMP() - INTERVAL '{lookback_hours}' HOURS
# MAGIC GROUP BY pipeline_name, environment, status

# COMMAND ----------

# DBTITLE 1,Query Data Quality Results
# MAGIC %sql
# MAGIC -- Query data quality validation results
# MAGIC CREATE OR REPLACE TEMPORARY VIEW recent_dq_results AS
# MAGIC SELECT 
# MAGIC     rule_name,
# MAGIC     rule_category,
# MAGIC     severity,
# MAGIC     target_table,
# MAGIC     COUNT(*) as violation_count,
# MAGIC     SUM(failed_records) as total_failed_records,
# MAGIC     MAX(validation_timestamp) as last_validated
# MAGIC FROM workspace.audit.audit_dq_results
# MAGIC WHERE validation_timestamp >= CURRENT_TIMESTAMP() - INTERVAL '{lookback_hours}' HOURS
# MAGIC GROUP BY rule_name, rule_category, severity, target_table

# COMMAND ----------

# DBTITLE 1,Generate Recovery Report
log_section_start(logger, f"Generating {report_type.upper()} Report", width=80)

try:
    # Collect pipeline metrics
    pipeline_metrics = spark.sql("SELECT * FROM recent_pipeline_runs").collect()
    
    # Collect DQ metrics
    dq_metrics = spark.sql("SELECT * FROM recent_dq_results").collect()
    
    # Build report data structure
    report = {
        "report_type": report_type,
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "lookback_hours": lookback_hours,
        "summary": {
            "total_pipeline_runs": len(pipeline_metrics),
            "total_dq_violations": len(dq_metrics),
            "pipelines_success_rate": 0.0,
            "critical_dq_issues": 0
        },
        "pipeline_metrics": [],
        "dq_metrics": []
    }
    
    # Calculate pipeline success rate
    total_runs = sum([row.run_count for row in pipeline_metrics])
    total_success = sum([row.success_count for row in pipeline_metrics])
    if total_runs > 0:
        report["summary"]["pipelines_success_rate"] = round((total_success / total_runs) * 100, 2)
    
    # Add pipeline metrics if requested
    if include_metrics:
        for row in pipeline_metrics:
            report["pipeline_metrics"].append({
                "pipeline_name": row.pipeline_name,
                "environment": row.environment,
                "status": row.status,
                "run_count": row.run_count,
                "rows_read": row.total_rows_read,
                "rows_written": row.total_rows_written,
                "avg_runtime_seconds": round(row.avg_runtime_seconds, 2),
                "last_run": str(row.last_run_time),
                "success_count": row.success_count,
                "failed_count": row.failed_count
            })
    
    # Add DQ metrics if requested
    if include_metrics:
        for row in dq_metrics:
            dq_entry = {
                "rule_name": row.rule_name,
                "category": row.rule_category,
                "severity": row.severity,
                "target_table": row.target_table,
                "violation_count": row.violation_count,
                "failed_records": row.total_failed_records,
                "last_validated": str(row.last_validated)
            }
            report["dq_metrics"].append(dq_entry)
            
            # Count critical issues
            if row.severity == "ERROR":
                report["summary"]["critical_dq_issues"] += row.violation_count
    
    logger.info(f"✓ Report generated successfully")
    log_metrics(logger, {
        "Total Pipeline Runs": total_runs,
        "Success Rate": f"{report['summary']['pipelines_success_rate']}%",
        "DQ Violations": len(dq_metrics),
        "Critical DQ Issues": report["summary"]["critical_dq_issues"]
    }, prefix="Report Summary")
    
except Exception as e:
    logger.error(f"Failed to generate report: {str(e)}")
    log_exception(logger, e, "During report generation")
    raise

finally:
    log_section_end(logger, "Report Generation", width=80)

# COMMAND ----------

# DBTITLE 1,Format Report Output
# Format output based on requested format
if output_format == "json":
    report_output = json.dumps(report, indent=2)
    print(report_output)
else:
    # Markdown format
    md_report = f"""# {report_type.upper()} AUDIT REPORT

**Generated:** {report['generated_at']}  
**Lookback Period:** {lookback_hours} hours

---

## Executive Summary

* **Total Pipeline Runs:** {report['summary']['total_pipeline_runs']}
* **Pipeline Success Rate:** {report['summary']['pipelines_success_rate']}%
* **Data Quality Violations:** {report['summary']['total_dq_violations']}
* **Critical DQ Issues:** {report['summary']['critical_dq_issues']}

---
"""
    
    if include_metrics and report["pipeline_metrics"]:
        md_report += "\n## Pipeline Execution Metrics\n\n"
        md_report += "| Pipeline | Environment | Status | Runs | Success | Failed | Avg Runtime (s) |\n"
        md_report += "|----------|-------------|--------|------|---------|--------|-----------------|\n"
        for pm in report["pipeline_metrics"]:
            md_report += f"| {pm['pipeline_name']} | {pm['environment']} | {pm['status']} | {pm['run_count']} | {pm['success_count']} | {pm['failed_count']} | {pm['avg_runtime_seconds']} |\n"
    
    if include_metrics and report["dq_metrics"]:
        md_report += "\n## Data Quality Issues\n\n"
        md_report += "| Rule | Category | Severity | Target Table | Violations | Failed Records |\n"
        md_report += "|------|----------|----------|--------------|------------|----------------|\n"
        for dq in report["dq_metrics"]:
            md_report += f"| {dq['rule_name']} | {dq['category']} | {dq['severity']} | {dq['target_table']} | {dq['violation_count']} | {dq['failed_records']} |\n"
    
    md_report += "\n---\n\n**Report Complete**"
    report_output = md_report
    displayHTML(f"<pre>{md_report}</pre>")

logger.info("Report formatting complete")

# COMMAND ----------

# DBTITLE 1,Save Report to Audit Table
# Optionally save report metadata to audit table
try:
    report_summary_df = spark.createDataFrame([(
        report_type,
        datetime.now(timezone.utc),
        lookback_hours,
        report["summary"]["total_pipeline_runs"],
        report["summary"]["pipelines_success_rate"],
        report["summary"]["total_dq_violations"],
        report["summary"]["critical_dq_issues"],
        report_output[:5000]  # Store first 5000 chars
    )], schema="report_type STRING, generated_at TIMESTAMP, lookback_hours INT, total_runs INT, success_rate DOUBLE, dq_violations INT, critical_issues INT, report_content STRING")
    
    # Create report archive table if it doesn't exist
    spark.sql("""
        CREATE TABLE IF NOT EXISTS workspace.audit.audit_report_archive (
            report_type STRING,
            generated_at TIMESTAMP,
            lookback_hours INT,
            total_runs INT,
            success_rate DOUBLE,
            dq_violations INT,
            critical_issues INT,
            report_content STRING
        )
        USING DELTA
        COMMENT 'Archive of generated audit reports'
    """)
    
    report_summary_df.write.mode("append").saveAsTable("workspace.audit.audit_report_archive")
    logger.info("✓ Report saved to audit_report_archive")
    
except Exception as e:
    logger.warning(f"Failed to save report to archive: {str(e)}")
    # Non-fatal - continue

# COMMAND ----------

# DBTITLE 1,Return Success
# Return report summary for orchestration
dbutils.notebook.exit(json.dumps({
    "status": "success",
    "report_type": report_type,
    "total_runs": report["summary"]["total_pipeline_runs"],
    "success_rate": report["summary"]["pipelines_success_rate"],
    "critical_issues": report["summary"]["critical_dq_issues"]
}))

# COMMAND ----------


