# LMIP Testing Guide

## Overview

This guide covers the LMIP test suite: structure, execution, and contribution guidelines.

## Test Suite Structure

### Priority-Based Test Organization

Tests are organized by risk level to ensure critical logic is validated first:

| Priority | Test Module | Risk Level | Focus Area |
|----------|-------------|------------|------------|
| 1 | `test_cdc_hash_logic.py` | **HIGHEST** | CDC hash computation and change detection |
| 2 | `test_identity_matching.py` | **HIGHEST** | Cross-source deduplication and identity keys |
| 3 | `test_sector_assignment.py` | **HIGH** | Keyword-based sector classification |
| 4 | `test_scd2_key_generation.py` | **HIGH** | SCD2 surrogate keys and versioning |
| 5 | `test_quarantine_routing.py` | **MEDIUM** | Data quality quarantine logic |
| 6 | `test_export_bundle_manifest.py` | **MEDIUM** | Publish contract validation |

### Test Markers

Tests are tagged with markers for selective execution:

* `@pytest.mark.cdc` — CDC hash logic tests
* `@pytest.mark.identity` — Identity matching tests
* `@pytest.mark.sector` — Sector assignment tests
* `@pytest.mark.scd2` — SCD2 key generation tests
* `@pytest.mark.quarantine` — Quarantine routing tests
* `@pytest.mark.manifest` — Export bundle manifest tests
* `@pytest.mark.unit` — Fast unit tests
* `@pytest.mark.integration` — Integration tests (require Spark)
* `@pytest.mark.slow` — Tests that take >1 second

## Installation

### Local Setup

```bash
# Install Python dependencies
pip install -r requirements.txt

# Or install test dependencies only
pip install pytest pytest-cov pytest-xdist pytest-timeout pytest-html pytest-spark
```

### Java Setup (Required for PySpark)

PySpark requires Java 11 or 17:

```bash
# macOS
brew install openjdk@11

# Ubuntu/Debian
sudo apt-get install openjdk-11-jdk

# Verify
java -version
```

## Running Tests

### Basic Execution

```bash
# Run all tests
pytest

# Run with verbose output
pytest -v

# Run with coverage report
pytest --cov=LMIP --cov-report=html
```

### Run by Priority

```bash
# Highest risk tests only (CDC + Identity)
pytest -m "cdc or identity"

# High risk tests (CDC + Identity + Sector + SCD2)
pytest -m "cdc or identity or sector or scd2"

# Medium risk tests
pytest -m "quarantine or manifest"

# Unit tests only (fast)
pytest -m "unit"

# Integration tests only
pytest -m "integration"
```

### Run by Test Module

```bash
# Run specific test file
pytest tests/test_cdc_hash_logic.py

# Run specific test class
pytest tests/test_cdc_hash_logic.py::TestCDCHashComputation

# Run specific test method
pytest tests/test_cdc_hash_logic.py::TestCDCHashComputation::test_hash_identical_records_match
```

### Parallel Execution

```bash
# Run tests in parallel (requires pytest-xdist)
pytest -n auto

# Run with 4 workers
pytest -n 4
```

### Fail Fast

```bash
# Stop on first failure
pytest -x

# Stop after 3 failures
pytest --maxfail=3
```

### Watch Mode

```bash
# Re-run tests on file changes (requires pytest-watch)
pip install pytest-watch
ptw
```

## Test Reports

### HTML Report

```bash
# Generate HTML report
pytest --html=tests/reports/report.html --self-contained-html

# Open report
open tests/reports/report.html
```

### JUnit XML (for CI integration)

```bash
pytest --junitxml=tests/reports/junit.xml
```

### Coverage Report

```bash
# Terminal report
pytest --cov=LMIP --cov-report=term-missing

# HTML report
pytest --cov=LMIP --cov-report=html

# XML report (for CI)
pytest --cov=LMIP --cov-report=xml

# Open HTML report
open htmlcov/index.html
```

## Continuous Integration

### GitHub Actions

Tests run automatically on:

* **Push** to `main`, `develop`, or `feature/*` branches
* **Pull Requests** to `main` or `develop`
* **Manual trigger** via GitHub Actions UI

### CI Workflow

The CI pipeline runs tests in stages:

1. **Highest Risk Tests** (CDC + Identity) — MUST PASS
2. **High Risk Tests** (Sector + SCD2)
3. **Medium Risk Tests** (Quarantine + Manifest)
4. **All Tests** (comprehensive coverage)

### Quality Gates

* ❌ **FAIL CI** if highest risk tests fail
* ⚠️ **WARN** if code coverage < 70%
* ✅ **PASS** if all tests pass and coverage >= 70%

### Viewing CI Results

1. Go to **Actions** tab in GitHub
2. Click on the workflow run
3. View test results in job summary
4. Download test artifacts for detailed reports

## Writing Tests

### Test Naming Conventions

```python
# Test file: test_<module_name>.py
# test_cdc_hash_logic.py

# Test class: Test<Functionality>
class TestCDCHashComputation:
    pass

# Test method: test_<scenario>
def test_hash_identical_records_match(self, spark):
    pass
```

### Test Structure (Arrange-Act-Assert)

```python
def test_hash_identical_records_match(self, spark, record_hash_function):
    # ARRANGE: Set up test data
    fields1 = ("acme corp", "developer", "remote usa")
    fields2 = ("acme corp", "developer", "remote usa")
    
    # ACT: Execute the logic
    hash1 = record_hash_function(*fields1)
    hash2 = record_hash_function(*fields2)
    
    # ASSERT: Verify results
    assert hash1 == hash2, "Identical records must produce identical hashes"
```

### Using Fixtures

```python
@pytest.fixture
def sample_bronze_jobs(spark):
    """Create sample bronze job records for testing"""
    data = [
        {"source_name": "remotive", "title": "Developer"},
        {"source_name": "arbeitnow", "title": "Engineer"},
    ]
    
    return spark.createDataFrame(data)

def test_with_fixture(spark, sample_bronze_jobs):
    # Use the fixture
    count = sample_bronze_jobs.count()
    assert count == 2
```

### Adding Test Markers

```python
import pytest

@pytest.mark.cdc
@pytest.mark.unit
def test_hash_computation(spark):
    pass

@pytest.mark.integration
@pytest.mark.slow
def test_end_to_end_pipeline(spark):
    pass
```

### Testing Spark DataFrames

```python
def test_dataframe_transformation(spark):
    # Create test DataFrame
    data = [("job_001", "Developer"), ("job_002", "Engineer")]
    df = spark.createDataFrame(data, ["job_id", "title"])
    
    # Apply transformation
    result_df = df.withColumn("title_upper", F.upper(F.col("title")))
    
    # Assert results
    results = result_df.collect()
    assert results[0].title_upper == "DEVELOPER"
    assert results[1].title_upper == "ENGINEER"
```

## Test Coverage Goals

### Overall Coverage

* **Target**: 80% code coverage
* **Minimum**: 70% code coverage

### Priority-Based Coverage

| Module | Priority | Target Coverage |
|--------|----------|-----------------|
| CDC Hash Logic | Highest | 95%+ |
| Identity Matching | Highest | 95%+ |
| Sector Assignment | High | 90%+ |
| SCD2 Key Generation | High | 90%+ |
| Quarantine Routing | Medium | 85%+ |
| Export Manifest | Medium | 85%+ |

## Debugging Tests

### Run with Debug Output

```bash
# Show print statements
pytest -s

# Show debug logs
pytest --log-cli-level=DEBUG

# Show local variables on failure
pytest -l
```

### Using PDB (Python Debugger)

```python
def test_with_debugger(spark):
    data = [("job_001", "Developer")]
    df = spark.createDataFrame(data, ["job_id", "title"])
    
    # Set breakpoint
    import pdb; pdb.set_trace()
    
    result = df.count()
    assert result == 1
```

### Isolating Failing Tests

```bash
# Run only failed tests from last run
pytest --lf

# Run failed first, then rest
pytest --ff
```

## Performance Testing

### Test Execution Time

```bash
# Show slowest 10 tests
pytest --durations=10

# Show all test durations
pytest --durations=0
```

### Timeout Tests

```python
import pytest

@pytest.mark.timeout(5)  # Fail if test takes >5 seconds
def test_with_timeout(spark):
    pass
```

## Common Patterns

### Testing for Exceptions

```python
def test_invalid_input_raises_error():
    with pytest.raises(ValueError, match="Invalid batch_id"):
        process_batch(batch_id=None)
```

### Parameterized Tests

```python
@pytest.mark.parametrize("input,expected", [
    ("hello", "HELLO"),
    ("world", "WORLD"),
    ("", ""),
])
def test_uppercase(input, expected):
    assert input.upper() == expected
```

### Mocking External Dependencies

```python
from unittest.mock import Mock, patch

@patch('requests.get')
def test_api_call(mock_get):
    mock_get.return_value.status_code = 200
    mock_get.return_value.json.return_value = {"data": "test"}
    
    result = fetch_data_from_api()
    assert result == {"data": "test"}
```

## Troubleshooting

### Spark Not Starting

```bash
# Check Java version
java -version

# Set JAVA_HOME
export JAVA_HOME=/path/to/java

# Check PySpark installation
python -c "import pyspark; print(pyspark.__version__)"
```

### Tests Hanging

* Check for infinite loops in test logic
* Add timeouts: `pytest --timeout=60`
* Run with verbose output: `pytest -v -s`

### Memory Issues

```bash
# Reduce Spark parallelism
export SPARK_LOCAL_PARALLELISM=2

# Increase Spark driver memory
export SPARK_DRIVER_MEMORY=4g
```

### Import Errors

```bash
# Ensure LMIP is in PYTHONPATH
export PYTHONPATH="${PYTHONPATH}:/path/to/LMIP"

# Or install in editable mode
pip install -e .
```

## Best Practices

### ✅ DO

* Write tests for **critical business logic** first
* Use **descriptive test names** that explain the scenario
* Keep tests **fast** and **isolated**
* Use **fixtures** for common test data
* Test **edge cases** and **boundary conditions**
* Mock **external dependencies** (APIs, databases)
* Commit tests **with the code** they test

### ❌ DON'T

* Test implementation details (test behavior, not internals)
* Write tests that depend on external state
* Use production data in tests
* Skip tests without documenting why
* Test framework code (e.g., Spark built-ins)
* Duplicate test logic across files

## Contributing Tests

### Pull Request Checklist

- [ ] Tests added for new functionality
- [ ] All existing tests pass
- [ ] Code coverage maintained or improved
- [ ] Test names are descriptive
- [ ] Edge cases covered
- [ ] Tests run in < 1 second (or marked as `@pytest.mark.slow`)
- [ ] Tests are properly marked with priority tags

### Test Review Guidelines

When reviewing tests:

1. **Correctness**: Does the test actually test what it claims?
2. **Coverage**: Are edge cases covered?
3. **Clarity**: Is the test easy to understand?
4. **Performance**: Does the test run fast?
5. **Isolation**: Does the test depend on external state?

## Resources

* [pytest documentation](https://docs.pytest.org/)
* [PySpark testing guide](https://spark.apache.org/docs/latest/api/python/user_guide/testing.html)
* [pytest-spark documentation](https://pytest-spark.readthedocs.io/)
* [Python testing best practices](https://realpython.com/pytest-python-testing/)

## Contact

For questions or issues with the test suite:

* Create an issue in the GitHub repository
* Reach out to the data engineering team
* Check the `#data-engineering` Slack channel

---

**Last Updated:** 2026-06-14  
**Owner:** Data Engineering Team  
**Status:** Living Document
