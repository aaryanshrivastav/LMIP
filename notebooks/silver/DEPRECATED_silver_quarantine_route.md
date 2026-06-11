# ⚠️ DEPRECATED: silver_quarantine_route

**Status**: Deprecated (2026-06)  
**Replacement**: `/LMIP/notebooks/quarantine/quarantine_manage`

## Why Deprecated?

The `silver_quarantine_route` notebook was originally created to manage quarantined records from within the Silver layer. However, LMIP architecture includes a **dedicated quarantine layer** that should own all quarantine management operations.

## What It Did

* List quarantined records
* Reinstate records back to processing
* Purge (discard) records permanently
* Show quarantine summary statistics

## Current Status

The notebook still exists but:
* **First cell** displays deprecation warning
* **All operations forward** to `/LMIP/notebooks/quarantine/quarantine_manage`
* **No workflows** reference this notebook
* **Architecture documentation** correctly references quarantine layer notebooks

## Use Instead

**New location**: `/LMIP/notebooks/quarantine/quarantine_manage`

All quarantine management operations are now centralized in the dedicated quarantine layer:

* `quarantine_route_records` - Route failed DQ records to quarantine
* **`quarantine_manage`** - List/reinstate/purge/summary operations
* `quarantine_review_apply` - Apply human review decisions
* `quarantine_reprocess_batch` - Reprocess records
* `quarantine_retention_cleanup` - Cleanup old records

See `/LMIP/notebooks/quarantine/README_QUARANTINE` for complete documentation.

## Removal Plan

**Do not delete** until:
1. Any hardcoded references in external tooling are updated
2. Historical job run logs no longer reference this notebook
3. All team members are aware of the new location

**Safe to remove after**: 2026-09 (3 months retention for audit purposes)
