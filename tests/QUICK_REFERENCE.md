# LMIP Test Suite — Quick Reference

## 🚀 Quick Start

```bash
# Run all tests
pytest

# Run highest priority (CDC + Identity)
pytest -m "cdc or identity"

# Run notebook tests only
pytest tests/notebooks/

# Run workflow tests only
pytest tests/workflows/

# Deploy test jobs to Databricks
python deployment/deploy_test_workflows.py --env dev --dry-run
```

## 📁 Test File Map

### Unit Tests (Logic)
```
tests/
├── test_cdc_hash_logic.py          # CDC change detection
├── test_identity_matching.py       # Cross-source deduplication
├── test_sector_assignment.py       # Sector classification
├── test_scd2_key_generation.py     # SCD2 versioning
├── test_quarantine_routing.py      # Data quality quarantine
└── test_export_bundle_manifest.py  # Export validation
```

### Notebook Tests
```
tests/notebooks/
├── test_bronze_notebooks.py         # 6 bronze notebooks
├── test_silver_notebooks.py         # 9 silver notebooks
├── test_intermediate_notebooks.py   # 7 intermediate notebooks
├── test_warehouse_notebooks.py      # 14 warehouse notebooks
├── test_init_notebooks.py           # 5 init notebooks
└── test_publish_notebooks.py        # 4 publish notebooks
```

### Workflow Tests
```
tests/workflows/
└── test_workflows_integration.py    # 8 workflow definitions
```

## 🎯 Common Commands

### Run by Priority
```bash
pytest -m "cdc or identity"     # Highest risk (MUST PASS)
pytest -m "sector or scd2"      # High risk
pytest -m "quarantine"          # Medium risk
```

### Run by Layer
```bash
pytest tests/notebooks/test_bronze_notebooks.py
pytest tests/notebooks/test_silver_notebooks.py
pytest tests/notebooks/test_intermediate_notebooks.py
pytest tests/notebooks/test_warehouse_notebooks.py
pytest tests/notebooks/test_init_notebooks.py
pytest tests/notebooks/test_publish_notebooks.py
```

### Run by Workflow
```bash
pytest tests/workflows/test_workflows_integration.py::TestInitWorkflow
pytest tests/workflows/test_workflows_integration.py::TestIngestionWorkflow
pytest tests/workflows/test_workflows_integration.py::TestRecoveryWorkflow
```

### Run with Options
```bash
pytest -v                        # Verbose output
pytest -s                        # Show print statements
pytest -x                        # Stop on first failure
pytest -n auto                   # Parallel execution
pytest --durations=10            # Show slowest 10 tests
pytest --lf                      # Run last failed only
pytest -m "not slow"             # Skip slow tests
```

### Coverage Reports
```bash
pytest --cov=LMIP --cov-report=html     # HTML report
pytest --cov=LMIP --cov-report=term     # Terminal report
pytest --cov=LMIP --cov-report=xml      # XML (for CI)
```

## 🏗️ Deployment Commands

```bash
# Deploy test workflows
python deployment/deploy_test_workflows.py --env dev

# Dry run (preview only)
python deployment/deploy_test_workflows.py --env dev --dry-run

# Deploy to production
python deployment/deploy_test_workflows.py --env prod

# Use existing cluster
python deployment/deploy_test_workflows.py --env dev --cluster-id abc123
```

## 📊 Test Coverage Map

### Notebooks by Layer (47 total)

| Layer | Count | Test File |
|-------|-------|-----------|
| **Bronze** | 6 | `test_bronze_notebooks.py` |
| **Silver** | 9 | `test_silver_notebooks.py` |
| **Intermediate** | 7 | `test_intermediate_notebooks.py` |
| **Warehouse** | 14 | `test_warehouse_notebooks.py` |
| **Init** | 5 | `test_init_notebooks.py` |
| **Publish** | 4 | `test_publish_notebooks.py` |

### Workflows (8 total)

| Workflow | Purpose |
|----------|---------|
| `init.json` | Environment initialization |
| `LMIPDataIngestion.json` | Bronze ingestion |
| `LMIPSilverProcessing.json` | Silver processing |
| `LMIPIntermediateProcessing.json` | Intermediate enrichment |
| `LMIPWarehouseBuild.json` | Warehouse build |
| `LMIPGoldBuild.json` | Gold aggregations |
| `publishing.json` | Export and publish |
| `recovery.json` | Rollback and replay |

## 🏷️ Test Markers

| Marker | Usage |
|--------|-------|
| `-m cdc` | CDC hash logic tests |
| `-m identity` | Identity matching tests |
| `-m sector` | Sector assignment tests |
| `-m scd2` | SCD2 key generation tests |
| `-m quarantine` | Quarantine routing tests |
| `-m manifest` | Export manifest tests |
| `-m unit` | Fast unit tests |
| `-m integration` | Integration tests |
| `-m slow` | Tests >1 second |

## 🔍 Finding Tests

### Find tests for a specific notebook
```bash
# Search test file
grep -n "bronze_write_api_response_log" tests/notebooks/test_bronze_notebooks.py

# Run tests for specific notebook
pytest tests/notebooks/test_bronze_notebooks.py -k "api_response_log"
```

### Find tests for a specific workflow
```bash
# List workflow test classes
grep "^class Test" tests/workflows/test_workflows_integration.py

# Run specific workflow tests
pytest tests/workflows/test_workflows_integration.py::TestRecoveryWorkflow -v
```

## 📖 Documentation

| File | Description |
|------|-------------|
| `tests/README.md` | Comprehensive test guide |
| `tests/workflows/README.md` | Workflow test documentation |
| `TEST_SUITE_SUMMARY.md` | Implementation summary |
| `docs/testing-guide.md` | Overall testing strategy |

## 🚨 Troubleshooting

### Test Not Found
```bash
# List all tests
pytest --collect-only

# List tests matching pattern
pytest --collect-only -k "bronze"
```

### Spark Issues
```bash
# Check Java version
java -version

# Set JAVA_HOME
export JAVA_HOME=/path/to/java

# Clear Spark metastore
rm -rf metastore_db/ spark-warehouse/
```

### Import Errors
```bash
# Add to PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:$(pwd)"
```

### Tests Hanging
```bash
# Add timeout
pytest --timeout=60

# Show detailed output
pytest -vvv -s
```

## 📞 Getting Help

```bash
# Show pytest help
pytest --help

# Show markers
pytest --markers

# Show fixtures
pytest --fixtures

# Show configuration
pytest --showlocals
```

## ✅ Pre-Commit Checklist

- [ ] Run highest priority tests: `pytest -m "cdc or identity"`
- [ ] Run affected layer tests: `pytest tests/notebooks/test_<layer>_notebooks.py`
- [ ] Check coverage: `pytest --cov=LMIP --cov-report=term`
- [ ] Run workflow validation: `pytest tests/workflows/ -m "not slow"`
- [ ] All tests pass ✅

## 🎯 CI/CD Quick Facts

* **GitHub Actions**: Runs on push/PR to main
* **Test Stages**: Highest → High → Medium → Notebook → Workflow → Full
* **Quality Gates**: Highest risk MUST PASS, coverage >= 70%
* **Artifacts**: Test reports, coverage, logs (30 day retention)
* **Databricks Jobs**: 3 test workflows (unit, notebook, workflow)

---

**For complete documentation, see [tests/README.md](README.md)**
