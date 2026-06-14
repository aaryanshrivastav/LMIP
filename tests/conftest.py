"""
LMIP Test Configuration and Shared Fixtures

Provides reusable fixtures for unit and integration tests.
Uses pytest-spark for Spark session management.
"""

import pytest
from datetime import datetime, timedelta
from pyspark.sql import SparkSession
from pyspark.sql.types import StructType, StructField, StringType, TimestampType, BooleanType, IntegerType, DoubleType
import hashlib


@pytest.fixture(scope="session")
def spark():
    """
    Create a Spark session for testing.
    Session-scoped to reuse across all tests.
    """
    spark = (
        SparkSession.builder
        .appName("LMIP_Unit_Tests")
        .master("local[2]")
        .config("spark.sql.shuffle.partitions", "2")
        .config("spark.default.parallelism", "2")
        .config("spark.sql.warehouse.dir", "/tmp/spark-warehouse")
        .config("spark.driver.memory", "2g")
        .getOrCreate()
    )
    
    # Set log level to WARN to reduce noise
    spark.sparkContext.setLogLevel("WARN")
    
    yield spark
    
    spark.stop()


@pytest.fixture(scope="function")
def clean_spark(spark):
    """
    Provide a clean Spark session for each test by dropping test tables.
    Function-scoped to ensure test isolation.
    """
    # Clean up any test tables before test
    test_databases = ["test_bronze", "test_silver", "test_warehouse", "test_metadata"]
    for db in test_databases:
        try:
            spark.sql(f"DROP DATABASE IF EXISTS {db} CASCADE")
        except:
            pass
    
    yield spark
    
    # Clean up after test
    for db in test_databases:
        try:
            spark.sql(f"DROP DATABASE IF EXISTS {db} CASCADE")
        except:
            pass


@pytest.fixture
def sample_bronze_jobs(spark):
    """
    Create sample bronze job records for testing.
    Returns a DataFrame with typical raw job postings.
    """
    data = [
        {
            "source_name": "remotive",
            "source_job_id": "rem_001",
            "source_job_key": "remotive_rem_001",
            "company_name": "Acme Corp",
            "title": "Senior Python Developer",
            "description": "Looking for experienced Python developer with Django and FastAPI",
            "location": "Remote, USA",
            "remote_type": "REMOTE",
            "source_url": "https://remotive.com/job/rem_001",
            "posted_at": datetime(2026, 6, 1, 10, 0, 0),
            "last_seen": datetime(2026, 6, 7, 10, 0, 0),
            "batch_id": "batch_20260607_001",
            "ingested_at": datetime(2026, 6, 7, 10, 5, 0)
        },
        {
            "source_name": "arbeitnow",
            "source_job_id": "arb_002",
            "source_job_key": "arbeitnow_arb_002",
            "company_name": "TechStart Inc.",
            "title": "Data Engineer - AWS",
            "description": "Data engineering role working with AWS, Spark, and Python",
            "location": "Berlin, Germany",
            "remote_type": "HYBRID",
            "source_url": "https://arbeitnow.com/job/arb_002",
            "posted_at": datetime(2026, 6, 2, 14, 30, 0),
            "last_seen": datetime(2026, 6, 7, 10, 0, 0),
            "batch_id": "batch_20260607_001",
            "ingested_at": datetime(2026, 6, 7, 10, 5, 0)
        },
        {
            "source_name": "remotive",
            "source_job_id": "rem_003",
            "source_job_key": "remotive_rem_003",
            "company_name": "Finance Solutions Ltd",
            "title": "Backend Engineer",
            "description": "Backend development for fintech platform using Java and Spring",
            "location": "London, UK",
            "remote_type": "ONSITE",
            "source_url": "https://remotive.com/job/rem_003",
            "posted_at": datetime(2026, 6, 3, 9, 0, 0),
            "last_seen": datetime(2026, 6, 7, 10, 0, 0),
            "batch_id": "batch_20260607_001",
            "ingested_at": datetime(2026, 6, 7, 10, 5, 0)
        }
    ]
    
    schema = StructType([
        StructField("source_name", StringType(), False),
        StructField("source_job_id", StringType(), False),
        StructField("source_job_key", StringType(), False),
        StructField("company_name", StringType(), True),
        StructField("title", StringType(), True),
        StructField("description", StringType(), True),
        StructField("location", StringType(), True),
        StructField("remote_type", StringType(), True),
        StructField("source_url", StringType(), True),
        StructField("posted_at", TimestampType(), True),
        StructField("last_seen", TimestampType(), True),
        StructField("batch_id", StringType(), False),
        StructField("ingested_at", TimestampType(), False)
    ])
    
    return spark.createDataFrame(data, schema)


@pytest.fixture
def sample_silver_jobs(spark):
    """
    Create sample silver job records with normalized fields.
    """
    data = [
        {
            "enterprise_job_id": "job_001",
            "source_name": "remotive",
            "source_job_id": "rem_001",
            "source_job_key": "remotive_rem_001",
            "company_name_raw": "Acme Corp",
            "company_name_norm": "acme corp",
            "title_raw": "Senior Python Developer",
            "title_normalized": "senior python developer",
            "description_raw": "Looking for experienced Python developer",
            "location_raw": "Remote, USA",
            "location_norm": "remote usa",
            "remote_type": "REMOTE",
            "source_url": "https://remotive.com/job/rem_001",
            "posted_at": datetime(2026, 6, 1, 10, 0, 0),
            "last_seen": datetime(2026, 6, 7, 10, 0, 0),
            "is_active": True,
            "soft_delete_flag": False,
            "soft_delete_reason": None,
            "record_hash": "abc123",
            "current_batch_id": "batch_20260607_001",
            "created_at": datetime(2026, 6, 7, 10, 5, 0),
            "updated_at": datetime(2026, 6, 7, 10, 5, 0)
        },
        {
            "enterprise_job_id": "job_002",
            "source_name": "arbeitnow",
            "source_job_id": "arb_002",
            "source_job_key": "arbeitnow_arb_002",
            "company_name_raw": "TechStart Inc.",
            "company_name_norm": "techstart inc",
            "title_raw": "Data Engineer - AWS",
            "title_normalized": "data engineer aws",
            "description_raw": "Data engineering role with AWS",
            "location_raw": "Berlin, Germany",
            "location_norm": "berlin germany",
            "remote_type": "HYBRID",
            "source_url": "https://arbeitnow.com/job/arb_002",
            "posted_at": datetime(2026, 6, 2, 14, 30, 0),
            "last_seen": datetime(2026, 6, 7, 10, 0, 0),
            "is_active": True,
            "soft_delete_flag": False,
            "soft_delete_reason": None,
            "record_hash": "def456",
            "current_batch_id": "batch_20260607_001",
            "created_at": datetime(2026, 6, 7, 10, 5, 0),
            "updated_at": datetime(2026, 6, 7, 10, 5, 0)
        }
    ]
    
    schema = StructType([
        StructField("enterprise_job_id", StringType(), False),
        StructField("source_name", StringType(), True),
        StructField("source_job_id", StringType(), True),
        StructField("source_job_key", StringType(), True),
        StructField("company_name_raw", StringType(), True),
        StructField("company_name_norm", StringType(), True),
        StructField("title_raw", StringType(), True),
        StructField("title_normalized", StringType(), True),
        StructField("description_raw", StringType(), True),
        StructField("location_raw", StringType(), True),
        StructField("location_norm", StringType(), True),
        StructField("remote_type", StringType(), True),
        StructField("source_url", StringType(), True),
        StructField("posted_at", TimestampType(), True),
        StructField("last_seen", TimestampType(), True),
        StructField("is_active", BooleanType(), True),
        StructField("soft_delete_flag", BooleanType(), True),
        StructField("soft_delete_reason", StringType(), True),
        StructField("record_hash", StringType(), True),
        StructField("current_batch_id", StringType(), True),
        StructField("created_at", TimestampType(), True),
        StructField("updated_at", TimestampType(), True)
    ])
    
    return spark.createDataFrame(data, schema)


def compute_record_hash(*fields):
    """
    Helper function to compute record hash from fields.
    Used for CDC change detection.
    
    Args:
        *fields: Variable number of field values
    
    Returns:
        str: MD5 hash of concatenated fields
    """
    content = "|".join([str(f) if f is not None else "" for f in fields])
    return hashlib.md5(content.encode()).hexdigest()


@pytest.fixture
def record_hash_function():
    """Provide the record hash function as a fixture"""
    return compute_record_hash


@pytest.fixture
def sample_sector_keywords():
    """Sample sector keywords for classification testing"""
    return {
        1: ["software", "developer", "engineer", "tech", "python", "java", "data"],
        2: ["finance", "banking", "fintech", "trading", "accountant"],
        3: ["healthcare", "medical", "nurse", "doctor", "clinical"],
        4: ["sales", "marketing", "account manager", "business development"],
        -1: ["unknown"]
    }


@pytest.fixture
def sample_dim_jobs(spark):
    """
    Create sample dimension job records for SCD2 testing.
    """
    data = [
        {
            "job_sk": 1,
            "enterprise_job_id": "job_001",
            "source_name": "remotive",
            "source_job_id": "rem_001",
            "canonical_role_id": "role_001",
            "company_sk": 100,
            "location_sk": 200,
            "sector_sk": 1,
            "role_sk": 300,
            "title_raw": "Senior Python Developer",
            "title_normalized": "senior python developer",
            "description_raw": "Looking for experienced Python developer",
            "location_raw": "Remote, USA",
            "remote_type": "REMOTE",
            "salary_min": None,
            "salary_max": None,
            "salary_currency": None,
            "posted_at": datetime(2026, 6, 1, 10, 0, 0),
            "record_hash": "abc123",
            "effective_from": datetime(2026, 6, 1, 10, 0, 0),
            "effective_to": None,
            "is_current": True,
            "created_at": datetime(2026, 6, 1, 10, 5, 0),
            "updated_at": datetime(2026, 6, 1, 10, 5, 0)
        }
    ]
    
    schema = StructType([
        StructField("job_sk", IntegerType(), False),
        StructField("enterprise_job_id", StringType(), False),
        StructField("source_name", StringType(), True),
        StructField("source_job_id", StringType(), True),
        StructField("canonical_role_id", StringType(), True),
        StructField("company_sk", IntegerType(), True),
        StructField("location_sk", IntegerType(), True),
        StructField("sector_sk", IntegerType(), True),
        StructField("role_sk", IntegerType(), True),
        StructField("title_raw", StringType(), True),
        StructField("title_normalized", StringType(), True),
        StructField("description_raw", StringType(), True),
        StructField("location_raw", StringType(), True),
        StructField("remote_type", StringType(), True),
        StructField("salary_min", DoubleType(), True),
        StructField("salary_max", DoubleType(), True),
        StructField("salary_currency", StringType(), True),
        StructField("posted_at", TimestampType(), True),
        StructField("record_hash", StringType(), True),
        StructField("effective_from", TimestampType(), True),
        StructField("effective_to", TimestampType(), True),
        StructField("is_current", BooleanType(), True),
        StructField("created_at", TimestampType(), True),
        StructField("updated_at", TimestampType(), True)
    ])
    
    return spark.createDataFrame(data, schema)
