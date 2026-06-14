# LMIP Workflow Tests

This directory contains integration tests for LMIP Databricks workflows.

## Overview

Workflow tests verify:
- **Workflow configuration validity** - JSON structure, task definitions, dependencies
- **Task dependency graphs** - No circular dependencies, correct execution order
- **End-to-end workflow execution** - Full pipeline runs from ingestion to publishing
- **Error handling and recovery** - Retry policies, timeouts, failure scenarios

## Test Files

### `test_workflows_integration.py`

Comprehensive integration tests for all LMIP workflows:

* **Configuration Tests**
  - `TestWorkflowConfiguration` - Validates JSON structure and task definitions
  - Verifies task dependencies are correctly defined
  - Detects circular dependencies

* **Workflow-Specific Tests**
  - `TestInitWorkflow` - Initialization workflow validation
  - `TestIngestionWorkflow` - Data ingestion workflow tests
  - `TestSilverProcessingWorkflow` - Silver layer processing tests
  - `TestIntermediateProcessingWorkflow` - Intermediate layer tests
  - `TestWarehouseBuildWorkflow` - Warehouse dimension/fact tests
  - `TestPublishingWorkflow` - Publishing workflow validation
  - `TestRecoveryWorkflow` - Recovery and rollback tests

* **Execution Tests** (marked as `@pytest.mark.integration`)
  - `TestWorkflowExecution` - End-to-end workflow runs
  - `TestWorkflowErrorHandling` - Error handling verification

## Running Tests

### Run All Workflow Tests

```bash
pytest tests/workflows/ -v
```

### Run Specific Test Classes

```bash
# Configuration tests only
pytest tests/workflows/test_workflows_integration.py::TestWorkflowConfiguration -v

# Recovery workflow tests
pytest tests/workflows/test_workflows_integration.py::TestRecoveryWorkflow -v
```

### Run Integration Tests

```bash
# Run full workflow execution tests (slow)
pytest tests/workflows/ -v -m integration
```

### Skip Integration Tests

```bash
# Skip slow integration tests
pytest tests/workflows/ -v -m "not integration"
```

## Deployment

Workflow tests can be deployed as Databricks jobs for CI/CD:

```bash
# Deploy test workflows to dev environment
python deployment/deploy_test_workflows.py --env dev

# Dry run (preview without deploying)
python deployment/deploy_test_workflows.py --env dev --dry-run

# Deploy to prod
python deployment/deploy_test_workflows.py --env prod
```

This creates three Databricks jobs:
1. `LMIP_Test_Unit_Tests_DEV` - Logic and unit tests
2. `LMIP_Test_Notebook_Integration_DEV` - Notebook integration tests
3. `LMIP_Test_Workflow_Integration_DEV` - Workflow integration tests

## Tested Workflows

| Workflow | File | Purpose |
|----------|------|---------|
| **init** | `init.json` | Environment initialization, schema creation, metadata seeding |
| **ingestion** | `LMIPDataIngestion.json` | Bronze layer data ingestion from sources |
| **silver** | `LMIPSilverProcessing.json` | Silver layer CDC, identity, sector, DQ, quarantine |
| **intermediate** | `LMIPIntermediateProcessing.json` | Company/role canonicalization, skill graphs |
| **warehouse** | `LMIPWarehouseBuild.json` | Dimensional model (dims, facts, bridges) |
| **gold** | `LMIPGoldBuild.json` | Gold layer aggregations and marts |
| **publishing** | `publishing.json` | Export bundles, CSV snapshots, Supabase sync |
| **recovery** | `recovery.json` | Batch rollback and replay/backfill |

## Test Coverage

### Configuration Coverage ✅

- [x] All workflow JSON files exist
- [x] JSON is valid and parseable
- [x] Tasks have required fields (task_key, task type)
- [x] Task dependencies reference valid tasks
- [x] No circular dependencies in task graphs

### Workflow-Specific Coverage ✅

- [x] Init workflow task ordering
- [x] Ingestion workflow has source tasks
- [x] Silver processing dependencies
- [x] Warehouse dimensions build before facts
- [x] Publishing manifest writes after exports
- [x] Recovery has rollback and replay tasks

### Execution Coverage ⚠️

- [ ] Full init workflow execution
- [ ] Full ingestion workflow execution
- [ ] End-to-end pipeline (init → ingestion → silver → intermediate → warehouse → publishing)
- [ ] Error handling and retry policies
- [ ] Recovery workflow execution

*Note: Full execution tests are marked as `@pytest.mark.slow` and skip by default. Run manually or in CI.*

## Adding New Workflow Tests

When adding a new workflow:

1. **Add workflow JSON file** to `/workflows/`
2. **Add workflow entry** to `WORKFLOWS` dict in `test_workflows_integration.py`
3. **Create workflow-specific test class** (e.g., `TestMyNewWorkflow`)
4. **Test configuration**:
   - Task structure
   - Dependencies
   - Ordering constraints
5. **Add to deployment script** in `deployment/deploy_test_workflows.py`

Example:

```python
class TestMyNewWorkflow:
    """Test my_new_workflow.json workflow."""

    def test_workflow_has_required_tasks(self, workflow_configs):
        """Verify workflow has expected tasks."""
        config = workflow_configs["my_new_workflow"]
        task_keys = [t["task_key"] for t in config["tasks"]]
        
        assert "task1" in task_keys
        assert "task2" in task_keys

    def test_task_dependencies(self, workflow_configs):
        """Verify task2 depends on task1."""
        config = workflow_configs["my_new_workflow"]
        tasks = {t["task_key"]: t for t in config["tasks"]}
        
        task2_deps = [d["task_key"] for d in tasks["task2"].get("depends_on", [])]
        assert "task1" in task2_deps
```

## CI/CD Integration

### GitHub Actions

Workflow tests run automatically on:
- Pull requests to `main` branch
- Push to `main` branch
- Scheduled nightly runs

See `.github/workflows/test.yml` for CI configuration.

### Test Reporting

Test results are published to:
- JUnit XML: `/tmp/test-results.xml`
- Console output with `-v` flag
- GitHub Actions test summary (when run in CI)

## Troubleshooting

### Test Failures

**Circular dependency detected**
- Review task `depends_on` fields in workflow JSON
- Use topological sort visualization to identify cycle

**Task dependency references non-existent task**
- Verify `depends_on` task_keys match actual task_key values
- Check for typos in task names

**Workflow execution timeout**
- Increase `timeout_seconds` in workflow config
- Investigate long-running tasks
- Consider parallelization

### Common Issues

**ModuleNotFoundError**
- Ensure `conftest.py` is in tests root
- Verify Spark fixtures are properly configured

**Databricks SDK errors**
- Check `DATABRICKS_HOST` and `DATABRICKS_TOKEN` env vars
- Verify workspace client has proper permissions

## Related Documentation

- [Testing Guide](../docs/testing-guide.md) - Overall testing strategy
- [Rollback Mechanism](../docs/rollback-mechanism.md) - Recovery workflow details
- [Workflow Dependency Graph](../workflows/workflow_dependency_graph.md) - Visual workflow dependencies
