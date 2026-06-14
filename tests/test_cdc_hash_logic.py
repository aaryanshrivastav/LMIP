"""
Test CDC Hash Logic (silver_detect_cdc)

Tests the Change Data Capture hash computation and change detection logic.
This is CRITICAL as incorrect hashing leads to missed updates or false positives.

Priority: HIGHEST RISK
"""

import pytest
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, TimestampType, BooleanType
from datetime import datetime, timedelta
import hashlib


class TestCDCHashComputation:
    """Test record hash computation for CDC change detection"""
    
    def test_hash_identical_records_match(self, spark, record_hash_function):
        """Identical records must produce identical hashes"""
        fields1 = ("acme corp", "senior python developer", "remote usa", "REMOTE", "https://example.com")
        fields2 = ("acme corp", "senior python developer", "remote usa", "REMOTE", "https://example.com")
        
        hash1 = record_hash_function(*fields1)
        hash2 = record_hash_function(*fields2)
        
        assert hash1 == hash2, "Identical records must produce identical hashes"
    
    def test_hash_different_records_differ(self, spark, record_hash_function):
        """Different records must produce different hashes"""
        fields1 = ("acme corp", "senior python developer", "remote usa", "REMOTE", "https://example.com")
        fields2 = ("acme corp", "senior java developer", "remote usa", "REMOTE", "https://example.com")
        
        hash1 = record_hash_function(*fields1)
        hash2 = record_hash_function(*fields2)
        
        assert hash1 != hash2, "Different records must produce different hashes"
    
    def test_hash_null_handling(self, spark, record_hash_function):
        """Hash function must handle NULL values correctly"""
        fields_with_null = ("acme corp", None, "remote usa", "REMOTE", None)
        fields_with_empty = ("acme corp", "", "remote usa", "REMOTE", "")
        
        hash_null = record_hash_function(*fields_with_null)
        hash_empty = record_hash_function(*fields_with_empty)
        
        # NULLs and empty strings should produce the same hash (both treated as empty)
        assert hash_null == hash_empty, "NULL and empty string should hash identically"
    
    def test_hash_field_order_matters(self, spark, record_hash_function):
        """Field order must affect hash (to catch field mapping errors)"""
        hash1 = record_hash_function("acme corp", "developer", "remote")
        hash2 = record_hash_function("developer", "acme corp", "remote")
        
        assert hash1 != hash2, "Field order must affect hash computation"
    
    def test_hash_whitespace_sensitivity(self, spark, record_hash_function):
        """Hash should be sensitive to whitespace differences"""
        hash1 = record_hash_function("acme corp", "senior developer")
        hash2 = record_hash_function("acme corp", "senior  developer")  # Double space
        
        assert hash1 != hash2, "Whitespace differences must affect hash"
    
    def test_hash_case_sensitivity(self, spark, record_hash_function):
        """Hash should be sensitive to case (tests are on normalized fields)"""
        hash1 = record_hash_function("acme corp", "senior developer")
        hash2 = record_hash_function("acme corp", "Senior Developer")
        
        assert hash1 != hash2, "Case differences must affect hash"


class TestCDCChangeDetection:
    """Test CDC change detection logic (INSERT, UPDATE, DELETE)"""
    
    def test_detect_inserts(self, spark):
        """New records in staging should be detected as INSERTs"""
        # Staging has records not in current
        staging_data = [
            ("staging_001", "remotive_new_001", "acme corp", "developer", "hash_new_1"),
            ("staging_002", "remotive_new_002", "techco", "engineer", "hash_new_2")
        ]
        
        staging_df = spark.createDataFrame(
            staging_data,
            ["enterprise_job_id", "source_job_key", "company_name_norm", "title_normalized", "record_hash"]
        )
        
        # Current is empty
        current_df = spark.createDataFrame(
            [],
            StructType([
                StructField("enterprise_job_id", StringType()),
                StructField("source_job_key", StringType()),
                StructField("record_hash", StringType())
            ])
        )
        
        # Detect inserts (left anti join)
        inserts_df = staging_df.alias("stg").join(
            current_df.alias("cur"),
            F.col("stg.source_job_key") == F.col("cur.source_job_key"),
            "left_anti"
        )
        
        insert_count = inserts_df.count()
        assert insert_count == 2, f"Expected 2 inserts, got {insert_count}"
    
    def test_detect_updates_hash_mismatch(self, spark):
        """Records with same key but different hash should be detected as UPDATEs"""
        staging_data = [
            ("job_001", "remotive_001", "acme corp", "senior developer", "hash_new"),
        ]
        
        staging_df = spark.createDataFrame(
            staging_data,
            ["enterprise_job_id", "source_job_key", "company_name_norm", "title_normalized", "record_hash"]
        )
        
        current_data = [
            ("job_001", "remotive_001", "hash_old"),
        ]
        
        current_df = spark.createDataFrame(
            current_data,
            ["enterprise_job_id", "source_job_key", "record_hash"]
        )
        
        # Detect updates (inner join with hash mismatch)
        updates_df = staging_df.alias("stg").join(
            current_df.alias("cur"),
            F.col("stg.source_job_key") == F.col("cur.source_job_key"),
            "inner"
        ).where(
            F.col("stg.record_hash") != F.col("cur.record_hash")
        )
        
        update_count = updates_df.count()
        assert update_count == 1, f"Expected 1 update, got {update_count}"
    
    def test_no_update_when_hash_matches(self, spark):
        """Records with same key and same hash should NOT be detected as updates"""
        staging_data = [
            ("job_001", "remotive_001", "acme corp", "senior developer", "hash_same"),
        ]
        
        staging_df = spark.createDataFrame(
            staging_data,
            ["enterprise_job_id", "source_job_key", "company_name_norm", "title_normalized", "record_hash"]
        )
        
        current_data = [
            ("job_001", "remotive_001", "hash_same"),
        ]
        
        current_df = spark.createDataFrame(
            current_data,
            ["enterprise_job_id", "source_job_key", "record_hash"]
        )
        
        # Detect updates
        updates_df = staging_df.alias("stg").join(
            current_df.alias("cur"),
            F.col("stg.source_job_key") == F.col("cur.source_job_key"),
            "inner"
        ).where(
            F.col("stg.record_hash") != F.col("cur.record_hash")
        )
        
        update_count = updates_df.count()
        assert update_count == 0, f"Expected 0 updates (hash matches), got {update_count}"
    
    def test_detect_deletes_source_aware(self, spark):
        """Deletes should only affect jobs from the SAME source (source-aware deletion)"""
        # Staging has jobs from 'remotive' source only
        staging_data = [
            ("job_001", "remotive", "remotive_001", datetime(2026, 6, 7)),
        ]
        
        staging_df = spark.createDataFrame(
            staging_data,
            ["enterprise_job_id", "source_name", "source_job_key", "last_seen"]
        )
        
        # Current has jobs from BOTH 'remotive' and 'arbeitnow'
        current_data = [
            ("job_001", "remotive", "remotive_001", datetime(2026, 5, 1), True),  # Old remotive job (stale)
            ("job_002", "remotive", "remotive_002", datetime(2026, 5, 1), True),  # Old remotive job (stale)
            ("job_003", "arbeitnow", "arbeitnow_003", datetime(2026, 5, 1), True),  # Old arbeitnow job
        ]
        
        current_df = spark.createDataFrame(
            current_data,
            ["enterprise_job_id", "source_name", "source_job_key", "last_seen", "is_active"]
        )
        
        # Staleness threshold: 7 days
        staleness_days = 7
        staleness_threshold = datetime(2026, 6, 7) - timedelta(days=staleness_days)
        current_source = "remotive"
        
        # Detect deletes - Source-aware: only remotive jobs not in staging and stale
        deletes_df = current_df.alias("cur").join(
            staging_df.alias("stg"),
            F.col("cur.source_job_key") == F.col("stg.source_job_key"),
            "left_anti"
        ).where(
            (F.col("cur.is_active") == True) &
            (F.col("cur.source_name") == current_source) &  # Source-aware
            (F.col("cur.last_seen") < F.lit(staleness_threshold))  # Stale
        )
        
        delete_count = deletes_df.count()
        deleted_ids = [row.enterprise_job_id for row in deletes_df.collect()]
        
        # Only job_002 should be deleted (remotive job not in staging and stale)
        # job_001 is in staging, job_003 is from different source
        assert delete_count == 1, f"Expected 1 delete, got {delete_count}"
        assert "job_002" in deleted_ids, "job_002 should be marked for deletion"
        assert "job_003" not in deleted_ids, "job_003 from different source should NOT be deleted"
    
    def test_no_delete_if_not_stale(self, spark):
        """Jobs not seen recently should NOT be deleted if within staleness window"""
        staging_data = []  # Empty staging (no jobs)
        
        staging_df = spark.createDataFrame(
            staging_data,
            StructType([
                StructField("enterprise_job_id", StringType()),
                StructField("source_name", StringType()),
                StructField("source_job_key", StringType())
            ])
        )
        
        # Current has a job seen recently (within 7 days)
        current_data = [
            ("job_001", "remotive", "remotive_001", datetime(2026, 6, 5), True),  # Seen 2 days ago
        ]
        
        current_df = spark.createDataFrame(
            current_data,
            ["enterprise_job_id", "source_name", "source_job_key", "last_seen", "is_active"]
        )
        
        staleness_days = 7
        staleness_threshold = datetime(2026, 6, 7) - timedelta(days=staleness_days)
        current_source = "remotive"
        
        # Detect deletes
        deletes_df = current_df.alias("cur").join(
            staging_df.alias("stg"),
            F.col("cur.source_job_key") == F.col("stg.source_job_key"),
            "left_anti"
        ).where(
            (F.col("cur.is_active") == True) &
            (F.col("cur.source_name") == current_source) &
            (F.col("cur.last_seen") < F.lit(staleness_threshold))
        )
        
        delete_count = deletes_df.count()
        assert delete_count == 0, f"Expected 0 deletes (not stale), got {delete_count}"


class TestCDCEdgeCases:
    """Test edge cases and boundary conditions"""
    
    def test_duplicate_staging_records_deduplication(self, spark):
        """Staging should deduplicate by source_job_key, keeping most recent"""
        # Staging has duplicates (same source_job_key, different processed_at)
        staging_data = [
            ("job_001", "remotive_001", "hash_old", datetime(2026, 6, 7, 10, 0)),
            ("job_001", "remotive_001", "hash_new", datetime(2026, 6, 7, 11, 0)),  # Most recent
        ]
        
        staging_df = spark.createDataFrame(
            staging_data,
            ["enterprise_job_id", "source_job_key", "record_hash", "processed_at"]
        )
        
        # Deduplicate by source_job_key, keep most recent by processed_at
        from pyspark.sql.window import Window
        
        window_spec = Window.partitionBy("source_job_key").orderBy(F.col("processed_at").desc())
        
        deduped_df = staging_df \
            .withColumn("row_num", F.row_number().over(window_spec)) \
            .filter(F.col("row_num") == 1) \
            .drop("row_num")
        
        result = deduped_df.collect()
        
        assert len(result) == 1, "Should have 1 record after deduplication"
        assert result[0].record_hash == "hash_new", "Should keep most recent record (hash_new)"
    
    def test_empty_staging_batch(self, spark):
        """Handle empty staging batch gracefully"""
        staging_df = spark.createDataFrame(
            [],
            StructType([
                StructField("source_job_key", StringType()),
                StructField("record_hash", StringType())
            ])
        )
        
        current_df = spark.createDataFrame(
            [("remotive_001", "hash_1")],
            ["source_job_key", "record_hash"]
        )
        
        # Should not crash, should result in 0 changes
        inserts_df = staging_df.alias("stg").join(
            current_df.alias("cur"),
            F.col("stg.source_job_key") == F.col("cur.source_job_key"),
            "left_anti"
        )
        
        assert inserts_df.count() == 0, "Empty staging should result in 0 inserts"
    
    def test_empty_current_table_first_load(self, spark):
        """First load into empty current table should insert all staging records"""
        staging_data = [
            ("job_001", "remotive_001", "hash_1"),
            ("job_002", "remotive_002", "hash_2"),
        ]
        
        staging_df = spark.createDataFrame(
            staging_data,
            ["enterprise_job_id", "source_job_key", "record_hash"]
        )
        
        current_df = spark.createDataFrame(
            [],
            StructType([
                StructField("enterprise_job_id", StringType()),
                StructField("source_job_key", StringType()),
                StructField("record_hash", StringType())
            ])
        )
        
        # All staging records should be inserts
        inserts_df = staging_df.alias("stg").join(
            current_df.alias("cur"),
            F.col("stg.source_job_key") == F.col("cur.source_job_key"),
            "left_anti"
        )
        
        assert inserts_df.count() == 2, "All staging records should be inserts on first load"
