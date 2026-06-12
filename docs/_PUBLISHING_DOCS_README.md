# ⭐ Publishing Documentation Quick Reference

**Start Here:** [Publishing_Index.md](./Publishing_Index.md) - Complete index to all publishing docs

---

## The Three Publishing Documents

LMIP has three complementary publishing documents. Use this guide to find the right one:

### 1. [Publishing.md](./Publishing.md) - Internal Workflow

**For:** Data engineers operating the LMIP platform  
**Covers:**
* Unity Catalog Volume exports  
* Supabase synchronization  
* CSV compression (gzip level 6)  
* MD5 checksums  
* Monitoring and troubleshooting  
* Infrastructure (secrets, connections)  

**Use When:**
* Running/debugging the publishing pipeline
* Modifying export workflow
* Setting up monitoring
* Troubleshooting sync failures

---

### 2. [Publishing_Contracts.md](./Publishing_Contracts.md) - Formal Specification

**For:** Platform architects and integration teams  
**Covers:**
* Export order and dependency graph  
* Semantic versioning (YYYY.WW.PATCH)  
* Manifest schema (JSON specification)  
* CSV bundle structure  
* SHA256 checksums  
* Incremental publishing strategy  
* Disaster recovery procedures  
* Quality gates and validation  

**Use When:**
* Designing downstream systems
* Implementing consumer loaders
* Building automated integrations
* Planning reproducible deployments
* Need formal contracts/specifications

---

### 3. [Consumer_Bootstrap.md](./Consumer_Bootstrap.md) - Quick Start Guide

**For:** Data consumers, analysts, dashboard developers  
**Covers:**
* CSV file access patterns  
* Supabase connection examples  
* Schema reference  
* Code examples (Python, SQL, JavaScript, R)  
* Quick queries and analysis  

**Use When:**
* First-time setup
* Learning available tables
* Writing consumer applications
* Quick ad-hoc analysis

---

## Implementation Scripts

See [../publish/README.md](../publish/README.md) for:

* **export_bundle.py** - Databricks export script
* **load_bundle.py** - Consumer import script
* **load_dimensions.sql** - Consumer schema DDL (dimensions)
* **load_facts.sql** - Consumer schema DDL (facts)
* **validate_import.sql** - Data quality validation

---

## Quick Decision Tree

```
What do you need to do?

├─ Operate the publishing pipeline?
│  └→ Publishing.md
│
├─ Consume data for analysis/dashboards?
│  └→ Consumer_Bootstrap.md
│
├─ Build an integration or downstream system?
│  └→ Publishing_Contracts.md
│
└─ Need implementation scripts?
   └→ ../publish/README.md
```

---

## Key Differences

| Aspect | Publishing.md | Publishing_Contracts.md |
|--------|---------------|-------------------------|
| **Audience** | Internal engineers | External integrators |
| **Storage** | UC Volumes only | Portable CSV bundles |
| **Versioning** | Timestamp filenames | Semantic (YYYY.WW.PATCH) |
| **Checksums** | MD5 | SHA256 |
| **Manifest** | Per-table JSON | Comprehensive bundle manifest |
| **Recovery** | Troubleshooting | Disaster recovery procedures |
| **Consumer Access** | Requires Databricks/Supabase | Fully reproducible offline |

---

**Updated:** 2026-06-12  
**Maintained by:** LMIP Platform Engineering Team