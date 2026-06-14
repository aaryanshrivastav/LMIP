# LMIP Pipeline Logging & Notification Standards

**Purpose:** Standardize pipeline logging and notification dispatch across all LMIP workflows to ensure reliable audit trails and operational alerting.

**Last Updated:** 2025-01-18  
**Status:** 🟢 **ACTIVE STANDARD** - All new/modified workflows must comply

---

## 📋 Overview

Every production workflow MUST have two terminal tasks:

1. **Log_Pipeline_Execution** - Logs execution metrics to `workspace.audit.audit_pipeline_runs`
2. **Notify_On_Failure** - Dispatches alerts when pipeline fails

These tasks ensure:
* Complete audit trail of all pipeline runs
* Reliable failure notifications
* Operational visibility and SLA tracking
* Compliance with data governance requirements

---

## 🎯 Standard Workflow Structure

```
┌─────────────────────────────────────┐
│  Processing Tasks (parallel/serial) │
│  • Task_1                           │
│  • Task_2                           │
│  • Task_3                           │
└────────────┬────────────────────────┘
             │
       ┌─────┴─────┐
       │           │
   ┌───▼───┐   ┌───▼─────────┐
   │  Log  │   │ Notify_On   │
   │   │   │   │   Failure   │
   └───────┘   └─────────────┘
  (ALL_DONE)   (AT_LEAST_ONE_FAILED)
```

---

## 📝 Task 1: Log_Pipeline_Execution

### Purpose
Log execution metrics to `workspace.audit.audit_pipeline_runs` for operational tracking, SLA monitoring, and compliance.

### Task Configuration

```json
{
  "task_key": "Log_Pipeline_Execution",
  "depends_on": [
    {"task_key": "All_Processing_Tasks"}
  ],
  "run_if": "ALL_DONE",
  "notebook_task": {
    "notebook_path": "/Workspace/Users/aaryan.shrivastav1403@gmail.com/LMIP/notebooks/audit/log_pipeline_run",
    "source": "WORKSPACE",
    "base_parameters": {
      "pipeline_name": "{{workflow_name}}",
      "run_id": "{{run_id}}",
      "status": "{{tasks.task_key.state}}",
      "start_time": "{{start_time}}",
      "rows_read": "{{cumulative_rows_read}}",
      "rows_written": "{{cumulative_rows_written}}",
      "catalog": "workspace",
      "schema": "audit"
    }
  },
  "timeout_seconds": 600,
  "max_retries": 2,
  "email_notifications": {},
  "environment_key": "Default"
}
```

### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `pipeline_name` | string | Workflow name | `"LMIP_Silver_Processing"` |
| `run_id` | string | Databricks run ID | `"{{run_id}}"` (auto-filled) |
| `status` | string | "SUCCESS" or "FAILED" | `"{{tasks.task_key.state}}"` |
| `start_time` | string | ISO timestamp or Unix millis | `"{{start_time}}"` |
| `rows_read` | int | Total rows read | `"1500000"` |
| `rows_written` | int | Total rows written | `"1450000"` |
| `catalog` | string | UC catalog | `"workspace"` |
| `schema` | string | UC schema | `"audit"` |

### Key Properties

* **`run_if: "ALL_DONE"`** - Runs regardless of success/failure
* **`depends_on`** - Lists all processing tasks
* **Path** - `/notebooks/audit/log_pipeline_run` (singular, not plural!)
* **Retries** - 2 max retries to ensure log is captured

### Dynamic Parameter Resolution

**Status Resolution:**
```python
# In workflow JSON, use task values syntax:
"status": "{{tasks.last_task.state}}"  # Resolves to SUCCESS/FAILED

# Or use conditional logic in notebook:
status = "FAILED" if any_task_failed else "SUCCESS"
```

**Rows Read/Written:**
```python
# Aggregate from task outputs
rows_read = sum([
    int(dbutils.jobs.taskValues.get(taskKey="Task_1", key="rows_read", default=0)),
    int(dbutils.jobs.taskValues.get(taskKey="Task_2", key="rows_read", default=0))
])

# Or use notebook return values
dbutils.notebook.exit(json.dumps({
    "rows_read": rows_read,
    "rows_written": rows_written
}))
```

---

## 🚨 Task 2: Notify_On_Failure

### Purpose
Dispatch real-time alerts when pipeline fails, enabling immediate operational response.

### Task Configuration

```json
{
  "task_key": "Notify_On_Failure",
  "depends_on": [
    {"task_key": "All_Processing_Tasks"}
  ],
  "run_if": "AT_LEAST_ONE_FAILED",
  "notebook_task": {
    "notebook_path": "/Workspace/Users/aaryan.shrivastav1403@gmail.com/LMIP/notebooks/audit/audit_notification_dispatch",
    "source": "WORKSPACE",
    "base_parameters": {
      "notification_type": "critical_alert",
      "alert_severity": "HIGH",
      "alert_title": "{{workflow_name}} Pipeline Failed",
      "alert_message": "Pipeline {{workflow_name}} (Run ID: {{run_id}}) failed. Check audit logs for details.",
      "alert_context": "{\\\"workflow_name\\\": \\\"{{workflow_name}}\\\", \\\"run_id\\\": \\\"{{run_id}}\\\", \\\"run_page_url\\\": \\\"{{run_page_url}}\\\"}",
      "recipient_list": "data-ops-team@company.com,aaryan.shrivastav1403@gmail.com",
      "channel": "email"
    }
  },
  "timeout_seconds": 600,
  "max_retries": 2,
  "email_notifications": {},
  "environment_key": "Default"
}
```

### Required Parameters

| Parameter | Type | Description | Example |
|-----------|------|-------------|---------|
| `notification_type` | string | `"critical_alert"` or `"daily_summary"` | `"critical_alert"` |
| `alert_severity` | string | `"HIGH"`, `"MEDIUM"`, or `"LOW"` | `"HIGH"` |
| `alert_title` | string | Email subject / Slack title | `"LMIP Silver Processing Failed"` |
| `alert_message` | string | Alert body | `"Pipeline failed. Check logs."` |
| `alert_context` | JSON | Additional context | `{"run_id": "123", "url": "..."}` |
| `recipient_list` | string | Comma-separated emails | `"ops@company.com"` |
| `channel` | string | `"email"`, `"slack"`, or `"webhook"` | `"email"` |

### Key Properties

* **`run_if: "AT_LEAST_ONE_FAILED"`** - Only runs on failure
* **`depends_on`** - Lists all processing tasks (same as Log task)
* **Path** - `/notebooks/audit/audit_notification_dispatch`
* **Retries** - 2 max retries to ensure alert is sent

### Severity Levels

| Severity | Use Case | Color | Example |
|----------|----------|-------|---------|
| `HIGH` | Data loss, SLA breach, critical failures | 🔴 Red | Silver processing complete failure |
| `MEDIUM` | Partial failures, degraded performance | 🟡 Yellow | DQ warnings, 50% task failures |
| `LOW` | Informational, non-critical issues | 🔵 Blue | Single task retry succeeded |

---

## ✅ Compliance Checklist

Before deploying any workflow, verify:

- [ ] **Log task present** with correct path `/log_pipeline_run` (singular)
- [ ] **Log task has `run_if: "ALL_DONE"`** to capture both success and failure
- [ ] **All required parameters** passed to log task: pipeline_name, run_id, status, start_time, rows_read, rows_written
- [ ] **Notification task present** with correct path `/audit_notification_dispatch`
- [ ] **Notification task has `run_if: "AT_LEAST_ONE_FAILED"`** to trigger only on failures
- [ ] **Recipient list configured** with operational email addresses
- [ ] **Both tasks depend on all processing tasks** to ensure they run last
- [ ] **Test in staging** before promoting to production

---

## 📊 Common Patterns

### Pattern 1: Sequential Processing

```
Task_A → Task_B → Task_C
          ↓
  Log_Pipeline_Execution (depends on Task_C)
  Notify_On_Failure (depends on Task_C)
```

### Pattern 2: Parallel Processing

```
     ┌─ Task_A ─┐
Root ├─ Task_B ─┤
     └─ Task_C ─┘
          ↓
  Log_Pipeline_Execution (depends on [Task_A, Task_B, Task_C])
  Notify_On_Failure (depends on [Task_A, Task_B, Task_C])
```

### Pattern 3: Multi-Stage

```
Stage_1 → Stage_2 → Stage_3
                      ↓
              Log_Pipeline_Execution (depends on Stage_3)
              Notify_On_Failure (depends on [Stage_1, Stage_2, Stage_3])
```

---

## 🔍 Verification

### Check Audit Logs

```sql
-- Verify pipeline runs are being logged
SELECT 
    pipeline_name,
    run_id,
    status,
    start_time,
    end_time,
    TIMESTAMPDIFF(SECOND, start_time, end_time) as duration_seconds,
    rows_read,
    rows_written
FROM workspace.audit.audit_pipeline_runs
WHERE pipeline_name = 'LMIP_Silver_Processing'
ORDER BY start_time DESC
LIMIT 10;
```

### Check Notification Logs

```sql
-- Verify notifications are being sent
SELECT 
    notification_id,
    notification_type,
    severity,
    title,
    channel,
    recipient_count,
    dispatch_time,
    status
FROM workspace.audit.audit_notification_log
WHERE severity = 'HIGH'
ORDER BY dispatch_time DESC
LIMIT 10;
```

---

## 🚫 Anti-Patterns (DO NOT DO)

### ❌ Wrong: Missing Log Task
```json
// NO! Every workflow needs a log task
{
  "tasks": [
    {"task_key": "Process_Data", ...}
    // Missing Log_Pipeline_Execution
  ]
}
```

### ❌ Wrong: Incorrect Path
```json
// NO! Path is log_pipeline_run (singular), not log_pipeline_runs
"notebook_path": ".../log_pipeline_runs"  // ❌ WRONG
"notebook_path": ".../log_pipeline_run"   // ✅ CORRECT
```

### ❌ Wrong: Missing run_if
```json
// NO! Log task must use ALL_DONE
{
  "task_key": "Log_Pipeline_Execution",
  "run_if": "ALL_SUCCESS",  // ❌ Won't capture failures
  ...
}
```

### ❌ Wrong: Incomplete Parameters
```json
// NO! Missing rows_read and rows_written
"base_parameters": {
  "pipeline_name": "MyPipeline",
  "run_id": "{{run_id}}",
  "status": "SUCCESS"
  // ❌ Missing: rows_read, rows_written, start_time
}
```

### ❌ Wrong: No Notification Task
```json
// NO! Every workflow needs notification dispatch
{
  "tasks": [
    {"task_key": "Process_Data", ...},
    {"task_key": "Log_Pipeline_Execution", ...}
    // ❌ Missing: Notify_On_Failure
  ]
}
```

---

## 🛠️ Implementation Checklist

### For New Workflows

1. Copy standardized Log and Notify tasks from this document
2. Update `pipeline_name` to match workflow name
3. Update `depends_on` to list all processing tasks
4. Configure `recipient_list` with operational emails
5. Test end-to-end in development environment
6. Deploy to production

### For Existing Workflows

1. Review current logging implementation against this standard
2. Fix incorrect paths (`log_pipeline_runs` → `log_pipeline_run`)
3. Add missing parameters (especially `rows_read`, `rows_written`)
4. Add missing notification dispatch task
5. Update `run_if` clauses if incorrect
6. Test in staging, then deploy

---

## 📚 Related Documentation

* **log_pipeline_run.py** - Core logging notebook (`notebooks/audit/log_pipeline_run.py`)
* **audit_notification_dispatch.ipynb** - Notification dispatcher (`notebooks/audit/audit_notification_dispatch.ipynb`)
* **common_logging.py** - Shared logging functions (`notebooks/common/common_logging.py`)
* **audit schema DDL** - `sql/ddl/audit_audit_pipeline_runs.sql`

---

## 🔄 Revision History

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-01-18 | 1.0 | Initial standard created | Data Engineering Team |

---

**Questions?** Contact the Data Platform Team or file an issue in the LMIP repository.
