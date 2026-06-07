# LMIP Workflow Dependency Graph

## High-Level Architecture Flow

```
┌──────────────────────────────────────────────────────────────────────────┐
│                          LMIP Data Pipeline                              │
│                      (Medallion Architecture)                            │
└──────────────────────────────────────────────────────────────────────────┘

  ┌─────────────┐
  │   SOURCE    │  External APIs (Remotive, Arbeitnow)
  │  (External) │  
  └──────┬──────┘
         │
         ▼
  ┌─────────────┐
  │   BRONZE    │  Raw Ingestion Layer
  │ (Snapshot)  │  ➜ bronze_job_snapshot
  └──────┬──────┘  ➜ bronze_api_response_log
         │          
         │  [LMIP_Daily_Ingestion]
         │
         ▼
  ┌─────────────┐
  │   SILVER    │  Standardization & Quality Control
  │ (Cleansed)  │  ➜ silver_jobs_current
  └──────┬──────┘  ➜ silver_job_changes
         │          ➜ silver_skill_mapping
         │  [LMIP_Silver_Processing]
         │
         ▼
  ┌─────────────┐
  │  SEMANTIC   │  Enrichment & Canonicalization
  │ (Enriched)  │  ➜ sem_job_role_map
  └──────┬──────┘  ➜ sem_company_map
         │          ➜ sem_sector_map
         │  [LMIP_Semantic_Processing]
         │
         ▼
  ┌─────────────┐
  │ WAREHOUSE   │  Dimensional Model (Star Schema)
  │ (Star Schema│  ➜ Dimensions (10)
  └──────┬──────┘  ➜ Facts (4)
         │          ➜ Bridges (1)
         │  [LMIP_Warehouse_Build]
         │
         ▼
  ┌─────────────┐
  │    GOLD     │  Pre-Aggregated Business Metrics
  │(BI Marts)   │  ➜ gold_salary_trends
  └──────┬──────┘  ➜ gold_skill_demand
         │          ➜ gold_hiring_trends
         │  [LMIP_Gold_Build]
         │
         ▼
  ┌─────────────┐
  │  PUBLISH    │  External Distribution
  │ (Consumer)  │  ➜ CSV Snapshots
  └─────────────┘  ➜ Supabase Postgres
                   
    [LMIP_Publishing]

         ┌──────────────────┐
         │  RECOVERY PATH   │  Manual Trigger
         │  (Error Handle)  │  [LMIP_Recovery]
         └──────────────────┘  
```

---

## Workflow Definitions Summary

### 1. LMIP_Daily_Ingestion
**Purpose**: Ingest job postings from external APIs to Bronze layer  
**Trigger**: Daily at midnight (periodic)  
**Duration**: ~20-30 minutes  
**Retry Strategy**: 2 retries with 30s intervals for API calls

**Task Flow**:
```
Ingest_Remotive ──┐
                  ├──► Bronze_Write_API_Log ──► Bronze_Write_Job_Snapshot
 Ingest_Arbeitnow ┘                               ↓
                                          Bronze_Dedupe_Raw_Payload
                                                   ↓
                                          Bronze_Finalize_Batch
```

**Key Tables Written**:
* `bronze.bronze_job_snapshot`
* `bronze.bronze_api_response_log`

**Failure Handling**: 
* API ingestion failures allow pipeline to continue (AT_LEAST_ONE_SUCCESS)
* Partial data captured with telemetry
* Email alerts on complete failure

---

### 2. LMIP_Silver_Processing
**Purpose**: Transform raw bronze data into cleansed, standardized silver tables  
**Trigger**: File arrival trigger after bronze batch completion  
**Duration**: ~45-60 minutes  
**Retry Strategy**: 2 retries with 60s intervals

**Task Flow**:
```
Silver_Standardize_Jobs
         ↓
Silver_Detect_CDC
         ↓
Silver_Apply_Soft_Delete_Restore
         ↓
Silver_DQ_Validate
         ↓
   ┌─────┴──────┐
   │            │
Silver_Skill   Silver_Sector
 Extract        Assign
   │            │
   └─────┬──────┘
         ↓
Silver_Job_Identity_Map
```

**Key Tables Written**:
* `silver.silver_jobs_current` (main fact table)
* `silver.silver_job_changes` (audit trail)
* `silver.silver_skill_mapping`
* `silver.silver_job_identity_map`

**Failure Handling**:
* CDC failures block downstream processing
* DQ validation failures quarantine records
* Skill/sector extraction run in parallel

---

### 3. LMIP_Semantic_Processing
**Purpose**: Enrich silver data with canonical entities and semantic mappings  
**Trigger**: File arrival trigger after silver processing completion  
**Duration**: ~60-90 minutes  
**Retry Strategy**: 2 retries with 120s intervals (LLM timeouts)

**Task Flow**:
```
      ┌────────────────┐
      │                │
Semantic_Role_Map   Semantic_Company_Canonicalize
      │                │
      └────────┬───────┘
               ↓
      Semantic_Sector_Normalize
               ↓
      Semantic_Skill_Catalog_Sync
               ↓
      Semantic_Skill_Graph_Build
               ↓
      Semantic_Review_Resolver (runs regardless of upstream status)
```

**Key Tables Written**:
* `semantic.sem_job_role_map`
* `semantic.sem_company_map`
* `semantic.sem_sector_map`
* `semantic.sem_skill_catalog`
* `semantic.sem_skill_graph`
* `silver.silver_semantic_review_queue`

**Failure Handling**:
* Low-confidence matches queue for human review
* LLM fallbacks optional (disabled by default)
* Review resolver runs even if upstream tasks fail (ALL_DONE)

---

### 4. LMIP_Warehouse_Build
**Purpose**: Build dimensional star schema warehouse model  
**Trigger**: File arrival trigger after semantic processing completion  
**Duration**: ~2-3 hours  
**Retry Strategy**: 2 retries for all tasks

**Task Flow**:
```
Phase 1: Conformed Dimensions (Parallel)
 ┌──────┬─────────┬──────────┬───────┬──────────┐
 │      │         │          │       │          │
Dim    Dim      Dim        Dim     Dim        Dim
Date   Source   Sector     Skill   Role       Location
 │      │         │          │       │          │
 └──────┴─────┬───┴──────────┴───────┴──────────┘
              ↓
Phase 2: Company Dimensions (Sequential)
         Dim_Company
              ↓
         Dim_Company_Alias
              ↓
Phase 3: SCD2 Job Dimension
         Dim_Job_SCD2
              ↓
Phase 4: Bridge Tables
         Bridge_Job_Skill
              ↓
Phase 5: Fact Tables (Parallel)
 ┌────────┬─────────────┬────────────┬─────────┐
 │        │             │            │         │
Fact     Fact          Fact        Fact       │
Job      Job           Salary      Pipeline   │
Postings Lifecycle                 Runs       │
 │        │             │            │         │
 └────────┴─────────────┴────────────┴─────────┘
```

**Key Tables Written**:
* **Dimensions (10)**: dim_date, dim_source, dim_sector, dim_skill, dim_role, dim_location, dim_company, dim_company_alias, dim_job_scd2
* **Bridge (1)**: bridge_job_skill
* **Facts (4)**: fact_job_postings, fact_job_lifecycle, fact_salary, fact_pipeline_runs

**Dependencies**:
* All Phase 1 dims load in parallel (no dependencies)
* dim_company requires dim_sector
* dim_company_alias requires dim_company
* dim_job_scd2 requires all Phase 1 & 2 dims
* Facts require respective dimensions

**Failure Handling**:
* Dimension failures block downstream fact loading
* SCD2 history preserved on re-runs
* Surrogate keys stable across loads

---

### 5. LMIP_Gold_Build
**Purpose**: Pre-aggregate business intelligence marts for dashboard consumption  
**Trigger**: File arrival trigger after warehouse build completion  
**Duration**: ~2-3 hours  
**Retry Strategy**: 2 retries with 120s intervals

**Task Flow**:
```
Phase 1: Core Analytics (Parallel)
 ┌──────────┬─────────────┬─────────────┬─────────────┬──────────────┬──────────────┐
 │          │             │             │             │              │              │
Gold       Gold          Gold          Gold          Gold           Gold
Salary     Skill         Hiring        Company       Location       Sector
Trends     Demand        Trends        Hiring        Trends         Overview
 │          │             │             │             │              │
 └──────────┴──────┬──────┴─────────────┴─────────────┴──────────────┘
                   ↓
Phase 2: Operational Monitoring
            Gold_Pipeline_Health (runs regardless of upstream status)
                   ↓
Phase 3: Industry-Specific (Parallel)
 ┌────────────────┬───────────────────┬───────────────────┐
 │                │                   │                   │
Gold             Gold                Gold
Hospitality      Hospitality         Hospitality
Hiring           Skills              Companies
 │                │                   │
 └────────────────┴───────────────────┴───────────────────┘
```

**Key Tables Written**:
* **Core**: gold_salary_trends, gold_skill_demand, gold_hiring_trends, gold_company_hiring, gold_location_trends, gold_sector_overview
* **Operational**: gold_pipeline_health
* **Industry**: gold_hospitality_hiring, gold_hospitality_skills, gold_hospitality_companies

**Dependencies**:
* Core analytics run in parallel from warehouse facts
* Industry-specific marts depend on respective core marts
* Pipeline health monitors all core marts (ALL_DONE)

**Failure Handling**:
* Independent marts allow partial completion
* Pre-aggregated for fast dashboard queries (<2s)
* Optimized with partitioning and Z-ordering

---

### 6. LMIP_Publishing
**Purpose**: Export gold layer data to external consumer systems  
**Trigger**: File arrival trigger after gold build completion  
**Duration**: ~1-2 hours  
**Retry Strategy**: 3 retries for Supabase sync, 2 for others

**Task Flow**:
```
Publish_CSV_Snapshot_Export
         ↓
Publish_Manifest_Write
         ↓
Publish_Load_Order_Check
         ↓
Publish_Supabase_Upsert
```

**Outputs**:
* CSV compressed snapshots to UC Volumes
* Schema manifests with compatibility checks
* Load order definitions for dependent tables
* Supabase Postgres sync for real-time queries

**Failure Handling**:
* Validation failures block Supabase sync
* Checksum verification at each stage
* Email alerts on success/failure
* Retry with exponential backoff for network issues

---

### 7. LMIP_Recovery
**Purpose**: Manual recovery and backfill workflow for data quality issues  
**Trigger**: Manual/On-demand (PAUSED by default)  
**Duration**: ~3-6 hours (depends on date range)  
**Retry Strategy**: Minimal retries (1-2) for idempotent operations

**Task Flow**:
```
Recovery_Bronze_Replay_Backfill
         ↓
Recovery_Silver_Reprocess
         ↓
Recovery_CDC_Reprocess
         ↓
Recovery_Semantic_Reprocess
         ↓
Recovery_Warehouse_Rebuild
         |
         └──────────────┐
                        │
Recovery_Quarantine_Manage (parallel)
         │              │
         └──────┬───────┘
                ↓
Recovery_Validation_Report (runs always)
```

**Parameters** (job-level):
* `start_date`: Beginning of backfill range (default: 2026-06-01)
* `end_date`: End of backfill range (default: 2026-06-07)
* `source_filter`: Comma-separated sources (default: remotive,arbeitnow)
* `batch_id`: Specific batch to reprocess (default: latest)
* `quarantine_action`: Action for quarantined records (default: review)
* `entity_type`: Entity type to manage (default: all)

**Use Cases**:
* Backfill missing dates
* Reprocess failed batches
* Recover quarantined records
* Full pipeline re-run after schema changes
* Historical data corrections

**Failure Handling**:
* Email alerts at start, success, and failure
* Validation report always generated (ALL_DONE)
* Idempotent operations allow safe re-runs
* Quarantine management runs in parallel

---

## Workflow Trigger Dependencies

```
TRIGGER TYPE: Periodic (Daily)
  └──► LMIP_Daily_Ingestion
         │
         └──► [File Trigger] dbfs:/databricks/workflows/triggers/bronze_batch_complete
                 │
                 └──► LMIP_Silver_Processing
                        │
                        └──► [File Trigger] dbfs:/databricks/workflows/triggers/silver_processing_complete
                               │
                               └──► LMIP_Semantic_Processing
                                      │
                                      └──► [File Trigger] dbfs:/databricks/workflows/triggers/semantic_processing_complete
                                             │
                                             └──► LMIP_Warehouse_Build
                                                    │
                                                    └──► [File Trigger] dbfs:/databricks/workflows/triggers/warehouse_build_complete
                                                           │
                                                           └──► LMIP_Gold_Build
                                                                  │
                                                                  └──► [File Trigger] dbfs:/databricks/workflows/triggers/gold_build_complete
                                                                         │
                                                                         └──► LMIP_Publishing

TRIGGER TYPE: Manual (PAUSED)
  └──► LMIP_Recovery (on-demand backfill and error recovery)
```

---

## SLA & Performance Targets

| Workflow | Target Duration | Max Timeout | Critical Path |
|----------|----------------|-------------|---------------|
| Daily_Ingestion | 20-30 min | 2 hours | Bronze writes |
| Silver_Processing | 45-60 min | 3 hours | CDC + Identity mapping |
| Semantic_Processing | 60-90 min | 4 hours | Skill graph build |
| Warehouse_Build | 2-3 hours | 5 hours | Dim_Job_SCD2 + Facts |
| Gold_Build | 2-3 hours | 4 hours | Core analytics |
| Publishing | 1-2 hours | 3 hours | CSV export + Supabase sync |
| Recovery | 3-6 hours | 6 hours | Full pipeline reprocess |

**End-to-End Pipeline**: Daily ingestion → Publishing = **6-9 hours**

---

## Retry & Error Handling Strategy

### Retry Configuration by Layer

| Layer | Max Retries | Retry Interval | Retry on Timeout |
|-------|-------------|----------------|------------------|
| **Ingestion (API)** | 2 | 30s | Yes |
| **Bronze** | 1-2 | 60s | No |
| **Silver** | 2 | 60s | No |
| **Semantic** | 2 | 120s | No |
| **Warehouse** | 2 | Standard | No |
| **Gold** | 2 | 120s | No |
| **Publishing** | 3 | 180s | Yes (Supabase only) |
| **Recovery** | 1-2 | Standard | No |

### Graceful Degradation Patterns

* **Ingestion**: AT_LEAST_ONE_SUCCESS - Pipeline continues if one source succeeds
* **Silver**: Quarantine bad records instead of failing entire batch
* **Semantic**: Low-confidence records routed to review queue
* **Warehouse**: Dimension failures block fact loading (data integrity)
* **Gold**: Parallel marts allow partial completion
* **Publishing**: Validation failures prevent corrupt data export

### Email Notifications

* **on_failure**: All workflows
* **on_success**: Publishing (confirmation), Recovery (completion report)
* **on_start**: Recovery only (manual trigger awareness)
* **no_alert_for_skipped_runs**: False (always alert)

---

## Operational Notes

### File Triggers
All inter-workflow triggers use file arrival pattern:  
**Path Template**: `dbfs:/databricks/workflows/triggers/{layer}_complete`

Each workflow writes a trigger file at completion:
```python
dbutils.fs.put(
    f"dbfs:/databricks/workflows/triggers/{layer}_complete",
    datetime.now().isoformat(),
    overwrite=True
)
```

### Performance Target
All workflows use `PERFORMANCE_OPTIMIZED` for faster execution with premium compute.

### Concurrency
All workflows set `max_concurrent_runs: 1` to prevent race conditions on Delta tables.

### Queue Management
All workflows enable job queueing to handle backlog during outages.

---

## Recovery Scenarios

### Scenario 1: API Ingestion Failure
**Symptom**: Remotive API times out  
**Action**: LMIP_Daily_Ingestion retries 2x, then continues with Arbeitnow data only  
**Recovery**: Run LMIP_Recovery with `source_filter=remotive` and date range

### Scenario 2: CDC Processing Failure
**Symptom**: Silver_Detect_CDC fails due to schema mismatch  
**Action**: Downstream workflows blocked at silver layer  
**Recovery**: Fix schema, run LMIP_Recovery to reprocess from bronze

### Scenario 3: Warehouse Dimension Failure
**Symptom**: dim_company load fails  
**Action**: All dependent tasks (dim_company_alias, dim_job_scd2, facts) blocked  
**Recovery**: Fix dimension issue, re-run LMIP_Warehouse_Build (idempotent)

### Scenario 4: Publishing Failure
**Symptom**: Supabase credentials expired  
**Action**: Pipeline completes through Gold, publishing fails  
**Recovery**: Update credentials, re-run LMIP_Publishing only

### Scenario 5: Historical Backfill
**Symptom**: Need to ingest 30 days of missing data  
**Action**: Run LMIP_Recovery with parameters:  
```json
{
  "start_date": "2026-05-08",
  "end_date": "2026-06-06",
  "source_filter": "remotive,arbeitnow"
}
```
**Expected**: Full pipeline reprocess from bronze → warehouse rebuild

---

## Future Enhancements

* **Incremental Warehouse Builds**: Load only changed dimensions/facts
* **Parallel Gold Marts**: Further optimize with independent notebook clusters
* **Real-time Streaming**: Replace batch ingestion with Spark Streaming
* **Auto-scaling**: Dynamic cluster sizing based on data volume
* **Data Quality Dashboards**: Real-time monitoring of DQ metrics
* **Alerting Integration**: Slack/PagerDuty for critical failures
* **Cost Optimization**: Photon acceleration for large aggregations
* **Multi-region Publishing**: Geo-distributed data distribution

---

**Generated**: 2026-06-07  
**Author**: LMIP Workflow Architect  
**Version**: 1.0