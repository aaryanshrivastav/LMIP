# Semantic Processing Pipeline

This folder contains the semantic processing notebooks that transform silver layer job data into canonical, semantically meaningful representations. These notebooks implement a **hybrid semantic matching strategy** combining deterministic rules with optional machine learning fallbacks.

---

## Overview

The semantic layer sits between **silver** (cleansed job data) and **gold/warehouse** layers (dimensional/aggregated data), enriching job postings with:

* **Canonical role taxonomies** - Map job titles to standard occupations
* **Skill catalogs and graphs** - Build comprehensive skill ontologies and relationships
* **Company canonicalization** - Resolve entity names and aliases
* **Industry sector normalization** - Map to standard taxonomies (NAICS, GICS, etc.)
* **Human-in-the-loop review** - Apply feedback to improve future matches

---

## Architecture

### Hybrid Matching Strategy

All semantic notebooks follow a **three-stage matching pipeline**:

```
┌─────────────────────────────────────────────────────────────┐
│  Stage 1: Dictionary/Alias Match                           │
│  • Fast exact lookup in canonical dictionaries              │
│  • Confidence: 1.0 (exact), 0.85-0.95 (alias/fuzzy)        │
│  • Handles 60-70% of records                                │
└─────────────────────────────────────────────────────────────┘
                         ↓ (if no match)
┌─────────────────────────────────────────────────────────────┐
│  Stage 2: Regex Pattern Match                               │
│  • Rule-based pattern matching                              │
│  • Confidence: 0.80-0.90                                    │
│  • Handles structured variations                            │
└─────────────────────────────────────────────────────────────┘
                         ↓ (if no match)
┌─────────────────────────────────────────────────────────────┐
│  Stage 3: NLP/LLM Fallback (Optional)                       │
│  • AI-powered semantic matching                             │
│  • Explicit timeout handling (default: 5s)                  │
│  • Confidence: 0.50-0.70                                    │
│  • Disabled by default for cost control                     │
└─────────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────────┐
│  Confidence Threshold Split                                 │
│  • High confidence (≥0.7) → Write to canonical tables       │
│  • Low confidence (<0.7) → Route to review queue            │
│  • No match → Review queue with reason                      │
└─────────────────────────────────────────────────────────────┘
```

### Error Handling

* **Timeouts**: All LLM calls wrapped with explicit timeout handlers
* **Failure graceful degradation**: Pipeline continues on LLM failures
* **Audit trail**: All matching decisions logged with method and confidence
* **Review queue**: Low-confidence and failed matches captured for human review

---

## Data Sources & Schema Structure

### Input
All semantic notebooks read from:
* **`workspace.silver.silver_jobs_current`** - Current snapshot of all job postings

### Output
Results are written to two schemas:

**`workspace.semantic.*`** - Canonical semantic mappings:
* `sem_job_role_map` - Job title to canonical role mappings
* `sem_company_map` - Company canonicalization results
* `sem_sector_map` - Industry sector normalizations
* `sem_skill_catalog` - Canonical skill taxonomy
* `sem_skill_graph` - Skill relationship graph

**`workspace.silver.silver_semantic_review_queue`** - Unified review queue for all low-confidence/unmatched records across all entity types

---

## Notebooks

### 1. `semantic_role_map`

**Purpose**: Map job titles to canonical roles

**Input**: `workspace.silver.silver_jobs_current` (title_normalized, title_raw columns)

**Output**:
* `workspace.semantic.sem_job_role_map` - High-confidence role mappings
* `workspace.silver.silver_semantic_review_queue` - Low-confidence/unmatched for review

**Matching Strategy**:
1. Dictionary lookup against in-memory role dictionary
2. Regex patterns (e.g., "Senior Software Engineer", "Lead Data Scientist")
3. Optional LLM fallback (disabled by default)

**Key Parameters**:
```python
CONFIG = {
    "confidence_threshold": 0.7,
    "llm_timeout_seconds": 5,
    "enable_llm_fallback": False  # Set True to enable
}
```

---

### 2. `semantic_company_canonicalize`

**Purpose**: Canonicalize company names using fuzzy matching and entity resolution

**Input**: `workspace.silver.silver_jobs_current` (company_name_raw, company_name_norm columns)

**Output**:
* `workspace.semantic.sem_company_map` - Company entity mappings
* `workspace.silver.silver_semantic_review_queue` - Ambiguous matches for review

**Matching Strategy**:
1. **Exact Match**: Direct lookup in in-memory canonical company dictionary
2. **Alias Match**: Check company aliases dictionary
3. **Fuzzy Match**: Levenshtein distance (threshold: 0.85)
4. **Normalization**: Remove common suffixes (Inc, Corp, Ltd, LLC)

---

### 3. `semantic_sector_normalize`

**Purpose**: Normalize industry sectors to standard taxonomies (NAICS, GICS, SIC)

**Input**: `workspace.silver.silver_jobs_current` (sector_assigned column, if available)

**Output**:
* `workspace.semantic.sem_sector_map` - Mapped to standard taxonomies
* `workspace.silver.silver_semantic_review_queue` - Unmatched sectors

**Supported Taxonomies**:
* **NAICS** - North American Industry Classification (2-6 digit hierarchical)
* **GICS** - Global Industry Classification Standard (8-digit, 4 levels)
* **SIC** - Standard Industrial Classification (legacy)
* **Custom** - Organization-specific taxonomies

**Note**: Currently uses sample/in-memory taxonomy data. Production deployment requires integration with external taxonomy sources or gold reference tables.

---

### 4. `semantic_skill_graph_build`

**Purpose**: Build skill relationship graphs from co-occurrence patterns and domain knowledge

**Input**: 
* `workspace.gold.skill_catalog` - Canonical skill taxonomy (or sample data if not available)
* `workspace.silver.silver_jobs_current` - Job descriptions for skill extraction

**Output**:
* `workspace.semantic.sem_skill_graph` - Graph edges (co-occurrence, prerequisite, similarity)
* Graph metrics (in-memory during execution)

**Graph Types**:
1. **Co-occurrence** - Skills frequently appearing together in job postings
2. **Prerequisite** - Directional skill dependencies (e.g., Deep Learning → Machine Learning)
3. **Similarity** - Skills in the same category

**Features**:
* Keyword-based skill extraction from job content
* Multiple edge type generation with confidence scores
* Bidirectional edges for undirected relationships
* Schema standardization for union operations

---

### 5. `semantic_review_resolver`

**Purpose**: Human-in-the-loop review system for low-confidence and unmatched records

**Input**: 
* `workspace.silver.silver_semantic_review_queue` - Unified queue for all entity types

**Output**:
* Updated canonical tables (based on review decisions)
* Updated dictionaries and aliases (learned patterns)
* `workspace.gold.semantic_review_audit` - Audit trail of human decisions

**Review Actions**:
* **Approve** - Accept suggested mapping
* **Create New** - Add new canonical entry
* **Update Mapping** - Correct suggested mapping
* **Reject** - Mark as invalid

**Note**: Currently includes simulated review logic. Production deployment requires integration with a review UI.

---

## Data Flow

```
workspace.silver.silver_jobs_current
         ↓
   [Semantic Notebooks]
         ↓
    ┌────┴────┐
    ↓         ↓
workspace.semantic.*   workspace.silver.silver_semantic_review_queue
(high confidence)      (low confidence / unmatched)
    ↓                          ↓
    |                  [Human Review]
    |                          ↓
    └──────←────────[Approved] 
            [Learned Patterns]
                   ↓
           [Update Dictionaries]
```

---

## Execution Order

**Recommended Pipeline Sequence**:

1. **Core Semantic Processing** (after standardization):
   * `semantic_role_map` - Map job titles to roles
   * `semantic_company_canonicalize` - Canonicalize companies
   * `semantic_sector_normalize` - Normalize sectors
   * `semantic_skill_graph_build` - Build skill relationship graphs

2. **Review and Learning** (periodic):
   * `semantic_review_resolver` - Process review queue
   * Re-run semantic notebooks with updated dictionaries

**Dependencies**: All semantic notebooks read from `workspace.silver.silver_jobs_current`, so the silver layer must be populated first.

---

## Key Configuration

### Confidence Thresholds

* **High accuracy**: 0.85-0.90 (fewer matches, higher quality)
* **Balanced**: 0.70-0.80 (recommended for production)
* **High coverage**: 0.50-0.65 (more matches, more review needed)

### LLM Fallback

* **Disable by default** for cost control
* **Always set timeouts** (5-10 seconds recommended)
* **Monitor costs** via audit logs
* Enable only when dictionary coverage is insufficient

---

## Current State & Productionization Notes

The current implementation is designed to work with the existing workspace data:

### What Works Now:
* All notebooks execute successfully against `workspace.silver.silver_jobs_current`
* In-memory reference data (dictionaries, taxonomies) for matching logic
* Proper schema definitions and write operations
* Review queue integration
* Comprehensive error handling

### What Requires Productionization:
1. **Reference Data Integration**:
   * Replace in-memory dictionaries with gold reference tables
   * Integrate external taxonomy sources (O*NET, ESCO, NAICS)
   * Build comprehensive company and skill catalogs

2. **Review UI**:
   * Replace simulated review logic with actual UI integration
   * Implement review workflow management
   * Add bulk review operations

3. **LLM Integration**:
   * Configure actual LLM endpoints if enabling AI fallback
   * Set up cost monitoring and rate limiting
   * Test timeout behavior under production load

4. **Monitoring & Alerting**:
   * Set up dashboards for match rates and confidence distributions
   * Alert on review queue size thresholds
   * Track processing times and failure rates

---

## Monitoring Metrics

1. **Match Rate**: `canonical_count / input_count` (Target: >80%)
2. **Review Queue Size**: `review_queue_count / input_count` (Target: <20%)
3. **Average Confidence**: By method and entity type
4. **Method Distribution**: Dictionary vs Regex vs LLM
5. **Processing Time**: Per notebook and per entity type

---

## Troubleshooting

### Low Match Rates (<60%)
1. Check dictionary coverage against actual data
2. Review regex patterns for common title formats
3. Lower confidence threshold temporarily
4. Enable LLM fallback (with cost monitoring)

### High Review Queue (>30%)
1. Lower confidence threshold to reduce queue
2. Improve dictionary/alias coverage from historical reviews
3. Add more regex patterns for common variations
4. Run review resolver more frequently to learn patterns

### Schema Errors
* Ensure all DataFrames use explicit schemas when creating from Python lists
* Check that column types match between source and target tables
* Verify column order when using union operations

---

## Maintenance Schedule

* **Weekly**: Run review resolver, monitor metrics, check queue sizes
* **Monthly**: Update dictionaries from review learnings, refresh external taxonomies
* **Quarterly**: Full dictionary audit, pattern analysis, performance tuning

---

## References

* **NAICS**: https://www.census.gov/naics/
* **GICS**: https://www.msci.com/gics
* **O*NET**: https://www.onetonline.org/
* **ESCO**: https://esco.ec.europa.eu/