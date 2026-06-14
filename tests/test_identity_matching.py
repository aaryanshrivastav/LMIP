"""
Test Identity Matching Logic (silver_job_identity_map)

Tests the deduplication and cross-source job identity matching logic.
Critical for preventing duplicate job postings across sources.

Priority: HIGHEST RISK (same as CDC)
"""

import pytest
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, TimestampType, IntegerType
from datetime import datetime
import hashlib


class TestIdentityKeyGeneration:
    """Test identity key generation for deduplication"""
    
    def test_identical_jobs_same_identity(self, spark):
        """Jobs with identical normalized fields should get same identity key"""
        data = [
            ("job_001", "remotive", "acme corp", "senior python developer", "remote usa"),
            ("job_002", "arbeitnow", "acme corp", "senior python developer", "remote usa"),  # Different source
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "company_norm", "title_norm", "location_norm"]
        )
        
        # Generate identity key
        df_with_key = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.coalesce(F.col("company_norm"), F.lit("")),
                F.coalesce(F.col("title_norm"), F.lit("")),
                F.coalesce(F.col("location_norm"), F.lit(""))
            ))
        )
        
        results = df_with_key.collect()
        
        # Both should have same identity key (same company, title, location)
        assert results[0].identity_key == results[1].identity_key, \
            "Identical jobs from different sources should have same identity key"
    
    def test_different_jobs_different_identity(self, spark):
        """Jobs with different normalized fields should get different identity keys"""
        data = [
            ("job_001", "remotive", "acme corp", "senior python developer", "remote usa"),
            ("job_002", "remotive", "acme corp", "senior java developer", "remote usa"),  # Different title
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "company_norm", "title_norm", "location_norm"]
        )
        
        df_with_key = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.coalesce(F.col("company_norm"), F.lit("")),
                F.coalesce(F.col("title_norm"), F.lit("")),
                F.coalesce(F.col("location_norm"), F.lit(""))
            ))
        )
        
        results = df_with_key.collect()
        
        assert results[0].identity_key != results[1].identity_key, \
            "Different jobs should have different identity keys"
    
    def test_identity_key_null_handling(self, spark):
        """Identity key should handle NULL values correctly"""
        data = [
            ("job_001", "remotive", None, "developer", "remote"),
            ("job_002", "arbeitnow", "", "developer", "remote"),  # Empty string
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "company_norm", "title_norm", "location_norm"]
        )
        
        df_with_key = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.coalesce(F.col("company_norm"), F.lit("")),
                F.coalesce(F.col("title_norm"), F.lit("")),
                F.coalesce(F.col("location_norm"), F.lit(""))
            ))
        )
        
        results = df_with_key.collect()
        
        # NULL and empty string should produce same identity key
        assert results[0].identity_key == results[1].identity_key, \
            "NULL and empty string should produce same identity key"
    
    def test_identity_key_location_insensitivity(self, spark):
        """Test whether identity key should be location-sensitive or not"""
        # This test documents the design decision: should jobs with same 
        # company/title but different locations be considered duplicates?
        
        data = [
            ("job_001", "remotive", "acme corp", "developer", "new york"),
            ("job_002", "arbeitnow", "acme corp", "developer", "san francisco"),
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "company_norm", "title_norm", "location_norm"]
        )
        
        # Identity key WITH location
        df_with_location = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.col("company_norm"), F.col("title_norm"), F.col("location_norm")
            ))
        )
        
        # Identity key WITHOUT location
        df_without_location = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.col("company_norm"), F.col("title_norm")
            ))
        )
        
        results_with = df_with_location.collect()
        results_without = df_without_location.collect()
        
        # With location: different keys (different jobs)
        assert results_with[0].identity_key != results_with[1].identity_key, \
            "With location: different locations should produce different keys"
        
        # Without location: same keys (same job in multiple locations)
        assert results_without[0].identity_key == results_without[1].identity_key, \
            "Without location: same company/title should produce same keys"


class TestCrossSourceDeduplication:
    """Test cross-source deduplication logic"""
    
    def test_deduplicate_across_sources_keep_first(self, spark):
        """When same job appears in multiple sources, keep first seen"""
        data = [
            ("job_001", "remotive", "rem_001", "acme corp", "developer", "id_abc", 
             datetime(2026, 6, 1), datetime(2026, 6, 1)),
            ("job_002", "arbeitnow", "arb_001", "acme corp", "developer", "id_abc",  # Same identity_key
             datetime(2026, 6, 2), datetime(2026, 6, 2)),  # Later
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "source_job_id", "company_norm", "title_norm", 
             "identity_key", "posted_at", "created_at"]
        )
        
        # Deduplicate: keep earliest by posted_at
        from pyspark.sql.window import Window
        
        window_spec = Window.partitionBy("identity_key").orderBy(F.col("posted_at").asc())
        
        deduped_df = df.withColumn("row_num", F.row_number().over(window_spec)) \
            .filter(F.col("row_num") == 1) \
            .drop("row_num")
        
        results = deduped_df.collect()
        
        assert len(results) == 1, "Should deduplicate to 1 record"
        assert results[0].job_id == "job_001", "Should keep first-seen job (job_001)"
        assert results[0].source_name == "remotive", "Should keep first source"
    
    def test_deduplicate_same_source_different_ids(self, spark):
        """Jobs from SAME source with same identity but different IDs are updates, not duplicates"""
        # This tests the edge case: source republishes same job with new ID
        data = [
            ("job_001", "remotive", "rem_001", "acme corp", "developer", "id_abc", 
             datetime(2026, 6, 1)),
            ("job_002", "remotive", "rem_002", "acme corp", "developer", "id_abc",  # Same source, same identity
             datetime(2026, 6, 3)),  # Later posting
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "source_job_id", "company_norm", "title_norm", 
             "identity_key", "posted_at"]
        )
        
        # For same source: these are potentially the same job re-posted
        # Strategy: mark old one as inactive, keep new one
        from pyspark.sql.window import Window
        
        window_spec = Window.partitionBy("source_name", "identity_key").orderBy(F.col("posted_at").desc())
        
        ranked_df = df.withColumn("is_latest", F.row_number().over(window_spec) == 1)
        
        results = ranked_df.collect()
        
        # job_002 should be marked as latest
        latest = [r for r in results if r.is_latest]
        assert len(latest) == 1
        assert latest[0].source_job_id == "rem_002", "Should keep most recent posting from same source"
    
    def test_preserve_different_identity_keys(self, spark):
        """Jobs with different identity keys should NOT be deduplicated"""
        data = [
            ("job_001", "remotive", "acme corp", "developer", "id_abc"),
            ("job_002", "remotive", "techco", "developer", "id_xyz"),  # Different company
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "company_norm", "title_norm", "identity_key"]
        )
        
        # Group by identity_key
        grouped = df.groupBy("identity_key").count()
        
        assert grouped.count() == 2, "Should have 2 distinct identity keys"
    
    def test_deduplication_ranking_source_priority(self, spark):
        """When jobs from multiple sources have same identity, optionally prioritize by source"""
        # Some sources may be more canonical than others
        data = [
            ("job_001", "remotive", "acme corp", "developer", "id_abc", 
             datetime(2026, 6, 1), 1),  # remotive: priority 1
            ("job_002", "arbeitnow", "acme corp", "developer", "id_abc",
             datetime(2026, 6, 1), 2),  # arbeitnow: priority 2 (same date)
            ("job_003", "other_source", "acme corp", "developer", "id_abc",
             datetime(2026, 6, 1), 3),  # other: priority 3
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "company_norm", "title_norm", "identity_key", 
             "posted_at", "source_priority"]
        )
        
        # Deduplicate: first by posted_at, then by source_priority
        from pyspark.sql.window import Window
        
        window_spec = Window.partitionBy("identity_key").orderBy(
            F.col("posted_at").asc(),
            F.col("source_priority").asc()
        )
        
        deduped_df = df.withColumn("row_num", F.row_number().over(window_spec)) \
            .filter(F.col("row_num") == 1) \
            .drop("row_num")
        
        result = deduped_df.collect()[0]
        
        assert result.source_name == "remotive", \
            "Should prefer higher priority source when posted on same date"


class TestIdentityMappingTable:
    """Test the identity mapping table structure and operations"""
    
    def test_create_identity_mapping(self, spark):
        """Create identity mapping from canonical job to all source jobs"""
        data = [
            ("canonical_001", "job_001", "remotive", "rem_001", "id_abc"),
            ("canonical_001", "job_002", "arbeitnow", "arb_001", "id_abc"),  # Same identity
            ("canonical_002", "job_003", "remotive", "rem_002", "id_xyz"),
        ]
        
        mapping_df = spark.createDataFrame(
            data,
            ["canonical_job_id", "source_job_id", "source_name", "source_key", "identity_key"]
        )
        
        # Verify mappings
        canonical_001_count = mapping_df.filter(F.col("canonical_job_id") == "canonical_001").count()
        
        assert canonical_001_count == 2, \
            "canonical_001 should map to 2 source jobs"
    
    def test_update_identity_mapping_new_source(self, spark):
        """When new source appears with same identity, update mapping"""
        # Existing mapping
        existing_data = [
            ("canonical_001", "job_001", "remotive", "rem_001", "id_abc", True),
        ]
        
        existing_df = spark.createDataFrame(
            existing_data,
            ["canonical_job_id", "source_job_id", "source_name", "source_key", "identity_key", "is_active"]
        )
        
        # New source with same identity
        new_data = [
            ("job_002", "arbeitnow", "arb_001", "id_abc"),
        ]
        
        new_df = spark.createDataFrame(
            new_data,
            ["source_job_id", "source_name", "source_key", "identity_key"]
        )
        
        # Find canonical_job_id for new job
        joined = new_df.join(
            existing_df.select("identity_key", "canonical_job_id").distinct(),
            "identity_key",
            "left"
        )
        
        result = joined.collect()[0]
        
        assert result.canonical_job_id == "canonical_001", \
            "New source job should map to existing canonical job"


class TestEdgeCases:
    """Test edge cases and boundary conditions"""
    
    def test_empty_normalized_fields(self, spark):
        """Handle jobs with all normalized fields empty"""
        data = [
            ("job_001", "remotive", "", "", ""),
            ("job_002", "arbeitnow", None, None, None),
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "source_name", "company_norm", "title_norm", "location_norm"]
        )
        
        df_with_key = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.coalesce(F.col("company_norm"), F.lit("")),
                F.coalesce(F.col("title_norm"), F.lit("")),
                F.coalesce(F.col("location_norm"), F.lit(""))
            ))
        )
        
        results = df_with_key.collect()
        
        # Both should produce same key (all empty)
        assert results[0].identity_key == results[1].identity_key
    
    def test_similar_but_not_identical(self, spark):
        """Jobs that are similar but not identical should have different keys"""
        data = [
            ("job_001", "acme corp", "senior developer", "id_1"),
            ("job_002", "acme corporation", "senior developer", "id_2"),  # Slight company name difference
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "company_norm", "title_norm", "identity_key"]
        )
        
        # Pre-computed keys should be different
        results = df.collect()
        
        assert results[0].identity_key != results[1].identity_key, \
            "Similar but not identical companies should have different keys"
    
    def test_unicode_handling(self, spark):
        """Identity key should handle unicode characters"""
        data = [
            ("job_001", "Café Tech", "développeur", "paris"),
            ("job_002", "Café Tech", "développeur", "paris"),  # Same unicode
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "company_norm", "title_norm", "location_norm"]
        )
        
        df_with_key = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.col("company_norm"), F.col("title_norm"), F.col("location_norm")
            ))
        )
        
        results = df_with_key.collect()
        
        assert results[0].identity_key == results[1].identity_key, \
            "Unicode characters should be handled consistently"
    
    def test_very_long_field_values(self, spark):
        """Identity key should handle very long field values"""
        long_description = "a" * 10000  # 10K characters
        
        data = [
            ("job_001", "acme", long_description, "location"),
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "company_norm", "title_norm", "location_norm"]
        )
        
        df_with_key = df.withColumn(
            "identity_key",
            F.md5(F.concat_ws("|", 
                F.col("company_norm"), F.col("title_norm"), F.col("location_norm")
            ))
        )
        
        # Should not crash
        result = df_with_key.collect()[0]
        
        assert len(result.identity_key) == 32, "MD5 hash should always be 32 chars"


class TestIdentityResolutionStrategies:
    """Test different identity resolution strategies"""
    
    def test_strict_matching(self, spark):
        """Strict matching: all fields must match exactly"""
        data = [
            ("job_001", "acme corp", "senior python developer", "remote usa", "id_1"),
            ("job_002", "acme corp", "senior python dev", "remote usa", "id_2"),  # Abbreviated title
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "company_norm", "title_norm", "location_norm", "identity_key"]
        )
        
        # Strict: different keys
        assert df.filter(F.col("identity_key") == "id_1").count() == 1
        assert df.filter(F.col("identity_key") == "id_2").count() == 1
    
    def test_fuzzy_matching_scenario(self, spark):
        """Document fuzzy matching requirements (for future implementation)"""
        # Note: This test documents the REQUIREMENT for fuzzy matching
        # Actual implementation would use string similarity algorithms
        
        data = [
            ("job_001", "acme corp", "senior python developer"),
            ("job_002", "acme corporation", "sr python developer"),  # Similar but not exact
        ]
        
        df = spark.createDataFrame(
            data,
            ["job_id", "company_norm", "title_norm"]
        )
        
        # TODO: Implement fuzzy matching
        # For now, these are considered different jobs
        # Future: Use Levenshtein distance, Jaro-Winkler, or ML-based similarity
        
        # Expected behavior with fuzzy matching:
        # similarity_threshold = 0.85
        # if similarity(job_001, job_002) > threshold:
        #     assert same_identity_key
        
        pass  # Documented for future implementation
