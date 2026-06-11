# LMIP Data Quality Validations

## Overview

This directory contains SQL validation rules for the LMIP data quality framework. Validations are organized into two parallel tracks with overlapping prefixes.

## Validation File Structure

### Track 1: Generic DQ Categories (Broad Coverage)
These files contain comprehensive validation rules across multiple layers:

* **01_completeness_validations.sql** - Required field checks, NULL validation across all layers
* **02_uniqueness_validations.sql** - Primary key uniqueness, surrogate key checks
* **03_freshness_validations.sql** - Data staleness checks, ingestion timestamp validation
* **04_duplicate_detection.sql** - Cross-layer duplicate detection
* **05_business_validations.sql** - Business rule compliance checks

### Track 2: Specific DQ Checks (Targeted)
These files contain focused validation rules for specific dimensions:

* **01_row_count_validation.sql** - Table-level row count anomaly detection
* **02_null_validation.sql** - Specific NULL checks for critical columns
* **03_referential_integrity.sql** - Foreign key relationship validation
* **04_referential_integrity_validations.sql** - Extended FK checks (warehouse layer)
* **05_gold_mart_validation.sql** - Gold layer aggregate validation

### Track 3: Domain-Specific Validations
Numbered sequentially from 06 onwards:

* **06_sector_classification_validations.sql** - Sector assignment and taxonomy checks
* **07_salary_validations.sql** - Salary range and currency validation
* **08_location_normalization_validations.sql** - Location standardization checks

## Why Two Parallel Tracks?

The dual numbering (01-05 appearing twice) reflects two validation philosophies:

1. **Generic validations** (Track 1) - Apply standard DQ patterns across all tables
2. **Specific validations** (Track 2) - Target known problem areas with detailed checks

Both tracks are executed independently. There is no execution order dependency between files with the same prefix number.

## Execution Order

1. Run Track 1 (generic) and Track 2 (specific) in parallel
2. Run Track 3 (domain-specific) after Tracks 1 & 2 complete
3. Aggregate results using `audit.audit_dq_results` table

## Adding New Validations

* **Generic pattern** → Add to Track 1 files (01-05_xxx_validations.sql)
* **Targeted fix** → Add to Track 2 files (01-05_xxx_validation.sql)
* **New domain** → Create new file with next sequential number (09+)

## File Naming Convention

* `XX_category_validations.sql` - Plural "validations" = broad multi-table checks
* `XX_category_validation.sql` - Singular "validation" = focused single-purpose checks
