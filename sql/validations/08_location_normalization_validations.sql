-- =====================================================
-- LMIP Data Quality Framework
-- Location Normalization Validation Rules
-- =====================================================
-- Purpose: Validate location data quality and normalization
-- Severity: WARNING for missing normalization, ERROR for invalid data
-- =====================================================

-- RULE: LOC_001 - Missing Location Normalization
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: QUEUE_FOR_NORMALIZATION
SELECT 
  'LOC_001' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  COLLECT_LIST(enterprise_job_id) AS failed_ids
FROM workspace.silver.silver_jobs_current
WHERE is_active = TRUE 
  AND location_raw IS NOT NULL 
  AND location_norm IS NULL
HAVING COUNT(*) > 0;

-- RULE: LOC_002 - Dim Location Valid ISO Country Codes
-- Target: workspace.warehouse.dim_location
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'LOC_002' AS rule_name,
  'Location Normalization' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  COLLECT_SET(iso_country_code) AS invalid_codes
FROM workspace.warehouse.dim_location
WHERE iso_country_code IS NOT NULL
  AND LENGTH(iso_country_code) != 2
HAVING COUNT(*) > 0;

-- RULE: LOC_003 - Valid Latitude Range
-- Target: workspace.warehouse.dim_location
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'LOC_003' AS rule_name,
  'Location Normalization' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  COLLECT_LIST(location_sk) AS failed_ids
FROM workspace.warehouse.dim_location
WHERE latitude IS NOT NULL 
  AND (latitude < -90 OR latitude > 90)
HAVING COUNT(*) > 0;

-- RULE: LOC_004 - Valid Longitude Range
-- Target: workspace.warehouse.dim_location
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'LOC_004' AS rule_name,
  'Location Normalization' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  COLLECT_LIST(location_sk) AS failed_ids
FROM workspace.warehouse.dim_location
WHERE longitude IS NOT NULL 
  AND (longitude < -180 OR longitude > 180)
HAVING COUNT(*) > 0;

-- RULE: LOC_005 - Location Hierarchy Consistency
-- Target: workspace.warehouse.dim_location
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'LOC_005' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  'Locations with city but no state/country' AS description
FROM workspace.warehouse.dim_location
WHERE city IS NOT NULL 
  AND (state IS NULL OR country IS NULL)
HAVING COUNT(*) > 0;

-- RULE: LOC_006 - Geocoding Completeness
-- Target: workspace.warehouse.dim_location
-- Severity: WARNING
-- Action: QUEUE_FOR_GEOCODING
SELECT 
  'LOC_006' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  COLLECT_LIST(location_sk) AS failed_ids
FROM workspace.warehouse.dim_location
WHERE active_flag = TRUE
  AND (latitude IS NULL OR longitude IS NULL)
  AND city IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: LOC_007 - Remote Type Consistency with Location
-- Target: workspace.silver.silver_jobs_current
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'LOC_007' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'silver' AS target_schema,
  'silver_jobs_current' AS target_table,
  'Jobs marked REMOTE but have specific location' AS description
FROM workspace.silver.silver_jobs_current
WHERE remote_type = 'REMOTE' 
  AND location_raw NOT LIKE '%Remote%'
  AND location_raw NOT LIKE '%Anywhere%'
  AND location_raw IS NOT NULL
HAVING COUNT(*) > 0;

-- RULE: LOC_008 - Location Natural Key Uniqueness
-- Target: workspace.warehouse.dim_location
-- Severity: ERROR
-- Action: QUARANTINE
SELECT 
  'LOC_008' AS rule_name,
  'Location Normalization' AS rule_category,
  'ERROR' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  'Duplicate location_nk values' AS description
FROM (
  SELECT location_nk, COUNT(*) as cnt
  FROM workspace.warehouse.dim_location
  WHERE location_nk IS NOT NULL
  GROUP BY location_nk
  HAVING COUNT(*) > 1
);

-- RULE: LOC_009 - ISO Region Code Format
-- Target: workspace.warehouse.dim_location
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'LOC_009' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  COLLECT_SET(iso_region_code) AS invalid_codes
FROM workspace.warehouse.dim_location
WHERE iso_region_code IS NOT NULL
  AND (LENGTH(iso_region_code) < 4 OR LENGTH(iso_region_code) > 6)
HAVING COUNT(*) > 0;

-- RULE: LOC_010 - Location Trends Data Quality
-- Target: workspace.gold.gold_location_trends
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'LOC_010' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'gold' AS target_schema,
  'gold_location_trends' AS target_table,
  'Location trends missing geographic details' AS description
FROM workspace.gold.gold_location_trends
WHERE location_name IS NULL 
   OR country IS NULL
HAVING COUNT(*) > 0;

-- RULE: LOC_011 - Consistent Location Names
-- Target: workspace.warehouse.dim_location
-- Severity: WARNING
-- Action: FLAG_FOR_REVIEW
SELECT 
  'LOC_011' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  'Similar location names with different coordinates' AS description
FROM (
  SELECT 
    LOWER(TRIM(location_name)) as normalized_name,
    COUNT(DISTINCT CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) as distinct_coords
  FROM workspace.warehouse.dim_location
  WHERE latitude IS NOT NULL AND longitude IS NOT NULL
  GROUP BY LOWER(TRIM(location_name))
  HAVING COUNT(DISTINCT CONCAT(CAST(latitude AS STRING), ',', CAST(longitude AS STRING))) > 1
);

-- RULE: LOC_012 - Inactive Locations Still Referenced
-- Target: workspace.warehouse.dim_location
-- Severity: WARNING
-- Action: LOG_WARNING
SELECT 
  'LOC_012' AS rule_name,
  'Location Normalization' AS rule_category,
  'WARNING' AS severity,
  COUNT(*) AS failed_records,
  CURRENT_TIMESTAMP() AS validation_timestamp,
  'warehouse' AS target_schema,
  'dim_location' AS target_table,
  'Inactive locations still referenced in fact tables' AS description
FROM workspace.warehouse.dim_location dl
WHERE dl.active_flag = FALSE
  AND EXISTS (
    SELECT 1 
    FROM workspace.warehouse.fact_job_postings fjp
    WHERE fjp.location_sk = dl.location_sk
  )
HAVING COUNT(*) > 0;

-- =====================================================
-- END OF LOCATION NORMALIZATION VALIDATIONS
-- =====================================================
