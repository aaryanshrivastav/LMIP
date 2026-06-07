# LMIP Consumer Bootstrap Guide

**Document Version**: 1.0  
**Last Updated**: 2026-06-07  
**Target Audience**: Data analysts, BI developers, external consumers

---

## Quick Start

LMIP publishes labor market intelligence data in two formats:
1. **CSV Files** - For batch analysis and data warehouse ingestion
2. **Supabase Postgres** - For real-time queries and dashboards

**Data Refresh**: Daily (completes by 8:00 AM UTC)

---

## Option 1: CSV File Access

### Prerequisites

* Access to Databricks workspace (for Unity Catalog Volumes)
* OR Presigned URL access (for external consumers, coming soon)

### File Locations

**Latest Snapshots**:
```
/Volumes/workspace/publish/snapshots/<YYYY>/<MM>/<DD>/
```

**Example**:
```
/Volumes/workspace/publish/snapshots/2026/06/07/gold_salary_trends_20260607_1430.csv.gz
```

### Available Tables

| Table Name | Description | Typical Size | Rows |
|------------|-------------|--------------|------|
| `gold_salary_trends` | Salary benchmarks with percentiles | 2 MB | 5K |
| `gold_skill_demand` | Skill trending and co-occurrence | 3 MB | 8K |
| `gold_hiring_trends` | Job posting velocity by sector/location | 4 MB | 12K |
| `gold_company_hiring` | Company-specific hiring activity | 2 MB | 5K |
| `gold_location_trends` | Geographic hiring patterns | 3 MB | 8K |
| `gold_sector_overview` | Sector-level KPIs | 1 MB | 2K |

### Python Example (PySpark)

```python
from pyspark.sql import SparkSession

spark = SparkSession.builder.getOrCreate()

# Read latest salary trends
df = spark.read \
    .option("header", "true") \
    .option("inferSchema", "true") \
    .csv("/Volumes/workspace/publish/snapshots/2026/06/07/gold_salary_trends_20260607_1430.csv.gz")

# Show schema
df.printSchema()

# Query data
df.filter(df.salary_p50 > 100000) \
  .select("sector_name", "role_name", "salary_p50", "observation_count") \
  .show()
```

### Python Example (Pandas)

```python
import pandas as pd

# Read CSV (gzip automatically decompressed)
df = pd.read_csv(
    "/Workspace/Users/aaryan.shrivastav1403@gmail.com/LMIP/publish/snapshots/2026/06/07/gold_salary_trends_20260607_1430.csv.gz",
    compression="gzip"
)

# View first rows
print(df.head())

# Filter and aggregate
salary_by_sector = df.groupby("sector_name")["salary_p50"].mean()
print(salary_by_sector)
```

### SQL Example (Databricks SQL)

```sql
-- Create external table pointing to CSV
CREATE OR REPLACE TABLE my_catalog.my_schema.salary_trends_csv
USING CSV
OPTIONS (
  path '/Volumes/workspace/publish/snapshots/2026/06/07/gold_salary_trends_20260607_1430.csv.gz',
  header 'true',
  inferSchema 'true'
);

-- Query the table
SELECT 
  sector_name,
  role_name,
  salary_p50 as median_salary,
  observation_count
FROM my_catalog.my_schema.salary_trends_csv
WHERE observation_count >= 10
ORDER BY salary_p50 DESC
LIMIT 20;
```

---

## Option 2: Supabase Postgres Access

### Prerequisites

* Supabase account (or Postgres client)
* Connection credentials (contact LMIP team)

### Connection Information

**Host**: `<provided-by-team>.supabase.co`  
**Port**: 5432  
**Database**: `postgres`  
**User**: `lmip_consumer` (read-only)  
**Password**: *Provided separately*  
**SSL Mode**: require

### Connection String Format

```
postgresql://lmip_consumer:<password>@<host>:5432/postgres?sslmode=require
```

### Python Example (psycopg2)

```python
import psycopg2
import pandas as pd

# Connect to Supabase
conn = psycopg2.connect(
    host="<host>.supabase.co",
    port=5432,
    database="postgres",
    user="lmip_consumer",
    password="<password>",
    sslmode="require"
)

# Query using pandas
query = """
    SELECT 
        sector_name,
        role_name,
        salary_p50,
        salary_p75,
        observation_count
    FROM gold_salary_trends
    WHERE salary_date_sk >= 20260601
        AND observation_count >= 10
    ORDER BY salary_p50 DESC
    LIMIT 100
"""

df = pd.read_sql(query, conn)
print(df.head())

conn.close()
```

### Python Example (SQLAlchemy)

```python
from sqlalchemy import create_engine
import pandas as pd

# Create engine
engine = create_engine(
    "postgresql://lmip_consumer:<password>@<host>.supabase.co:5432/postgres?sslmode=require"
)

# Query data
df = pd.read_sql(
    "SELECT * FROM gold_skill_demand WHERE demand_date_sk >= 20260601",
    engine
)

print(df.head())
```

### JavaScript Example (Supabase Client)

```javascript
import { createClient } from '@supabase/supabase-js'

const supabaseUrl = 'https://<your-project>.supabase.co'
const supabaseKey = '<your-anon-key>'
const supabase = createClient(supabaseUrl, supabaseKey)

// Query salary trends
const { data, error } = await supabase
  .from('gold_salary_trends')
  .select('*')
  .gte('salary_date_sk', 20260601)
  .gte('observation_count', 10)
  .order('salary_p50', { ascending: false })
  .limit(100)

if (error) console.error(error)
else console.log(data)
```

### R Example (RPostgres)

```r
library(DBI)
library(RPostgres)

# Connect
con <- dbConnect(
  Postgres(),
  host = "<host>.supabase.co",
  port = 5432,
  dbname = "postgres",
  user = "lmip_consumer",
  password = "<password>",
  sslmode = "require"
)

# Query
df <- dbGetQuery(con, "
  SELECT sector_name, salary_p50, observation_count
  FROM gold_salary_trends
  WHERE salary_date_sk >= 20260601
  ORDER BY salary_p50 DESC
  LIMIT 20
")

print(df)

dbDisconnect(con)
```

---

## Schema Reference

### gold_salary_trends

**Purpose**: Salary benchmarks with percentile distributions

**Grain**: Date × Sector × Role × Location (with rollups)

**Key Columns**:

| Column | Type | Description |
|--------|------|-------------|
| `salary_trend_sk` | BIGINT | Surrogate key |
| `salary_date_sk` | INT | Date in YYYYMMDD format |
| `sector_name` | VARCHAR | Industry sector |
| `role_name` | VARCHAR | Job role |
| `location_name` | VARCHAR | Geographic location |
| `salary_p25` | DECIMAL | 25th percentile salary |
| `salary_p50` | DECIMAL | Median salary |
| `salary_p75` | DECIMAL | 75th percentile salary |
| `salary_p90` | DECIMAL | 90th percentile salary |
| `observation_count` | INT | Number of observations |
| `delta_vs_prev_month` | DECIMAL | Change from prior month |
| `pct_change_vs_prev_month` | DECIMAL | % change from prior month |

**Rollup Logic**:
* `sector_name IS NULL` → Total across all sectors
* `role_name IS NULL` → Total across all roles
* `location_name IS NULL` → Total across all locations

**Example Query**:
```sql
-- Get median salary by sector for last 30 days
SELECT 
  sector_name,
  AVG(salary_p50) as avg_median_salary,
  SUM(observation_count) as total_observations
FROM gold_salary_trends
WHERE salary_date_sk >= DATE_FORMAT(CURRENT_DATE - INTERVAL 30 DAYS, 'yyyyMMdd')
  AND role_name IS NULL  -- Sector-level rollup
  AND location_name IS NULL
GROUP BY sector_name
ORDER BY avg_median_salary DESC;
```

---

### gold_skill_demand

**Purpose**: Skill trending and co-occurrence patterns

**Grain**: Date × Skill × Sector × Role

**Key Columns**:

| Column | Type | Description |
|--------|------|-------------|
| `skill_demand_sk` | BIGINT | Surrogate key |
| `demand_date_sk` | INT | Date in YYYYMMDD format |
| `skill_name` | VARCHAR | Skill name |
| `sector_name` | VARCHAR | Industry sector |
| `role_name` | VARCHAR | Job role |
| `job_postings_requiring_skill` | INT | Count of jobs requiring skill |
| `skill_rank` | INT | Rank by demand (1=most demanded) |
| `skill_velocity` | DECIMAL | Week-over-week % change |
| `co_occurring_skills` | TEXT | JSON array of top 5 co-occurring skills |
| `observation_count` | INT | Number of observations |

**Example Query**:
```sql
-- Get top 10 trending skills (highest velocity)
SELECT 
  skill_name,
  job_postings_requiring_skill,
  skill_velocity,
  observation_count
FROM gold_skill_demand
WHERE demand_date_sk = DATE_FORMAT(CURRENT_DATE, 'yyyyMMdd')
  AND sector_name IS NULL  -- Total across sectors
  AND role_name IS NULL
ORDER BY skill_velocity DESC
LIMIT 10;
```

---

### gold_hiring_trends

**Purpose**: Job posting velocity and hiring activity indicators

**Grain**: Date × Sector × Location × Role

**Key Columns**:

| Column | Type | Description |
|--------|------|-------------|
| `hiring_trend_sk` | BIGINT | Surrogate key |
| `trend_date_sk` | INT | Date in YYYYMMDD format |
| `sector_name` | VARCHAR | Industry sector |
| `location_name` | VARCHAR | Geographic location |
| `role_name` | VARCHAR | Job role |
| `new_postings_count` | INT | New jobs posted |
| `updated_postings_count` | INT | Jobs updated |
| `deleted_postings_count` | INT | Jobs removed |
| `active_postings_count` | INT | Total active jobs |
| `net_change` | INT | New - Deleted |
| `posting_velocity` | DECIMAL | 7-day moving average |
| `week_over_week_change` | DECIMAL | WoW % change |

**Example Query**:
```sql
-- Get hiring activity by sector for last 7 days
SELECT 
  sector_name,
  SUM(new_postings_count) as total_new,
  SUM(deleted_postings_count) as total_deleted,
  SUM(net_change) as net_hiring_change,
  AVG(posting_velocity) as avg_velocity
FROM gold_hiring_trends
WHERE trend_date_sk >= DATE_FORMAT(CURRENT_DATE - INTERVAL 7 DAYS, 'yyyyMMdd')
  AND location_name IS NULL
  AND role_name IS NULL
GROUP BY sector_name
ORDER BY net_hiring_change DESC;
```

---

## Common Analysis Patterns

### Pattern 1: Time-Series Trend Analysis

**Use Case**: Track median salary changes over time for a specific sector

```sql
SELECT 
  DATE(CAST(salary_date_sk AS STRING), 'yyyyMMdd') as trend_date,
  salary_p50 as median_salary,
  delta_vs_prev_month,
  observation_count
FROM gold_salary_trends
WHERE sector_name = 'Technology'
  AND role_name IS NULL
  AND location_name IS NULL
  AND salary_date_sk >= 20260101
ORDER BY trend_date;
```

### Pattern 2: Drill-Down Analysis

**Use Case**: Start with sector totals, drill into specific roles

```sql
-- Level 1: Sector totals
SELECT sector_name, SUM(observation_count) as total_obs
FROM gold_salary_trends
WHERE role_name IS NULL AND location_name IS NULL
GROUP BY sector_name;

-- Level 2: Drill into specific sector
SELECT role_name, SUM(observation_count) as total_obs
FROM gold_salary_trends
WHERE sector_name = 'Technology' AND location_name IS NULL
GROUP BY role_name;

-- Level 3: Drill into specific role + location
SELECT location_name, salary_p50, observation_count
FROM gold_salary_trends
WHERE sector_name = 'Technology' 
  AND role_name = 'Software Engineer'
ORDER BY salary_p50 DESC;
```

### Pattern 3: Comparative Analysis

**Use Case**: Compare skill demand across sectors

```sql
SELECT 
  skill_name,
  sector_name,
  job_postings_requiring_skill,
  skill_rank
FROM gold_skill_demand
WHERE demand_date_sk = DATE_FORMAT(CURRENT_DATE, 'yyyyMMdd')
  AND skill_name IN ('Python', 'SQL', 'JavaScript')
  AND role_name IS NULL
ORDER BY skill_name, job_postings_requiring_skill DESC;
```

---

## BI Tool Integration

### Tableau

1. Connect to Postgres data source
2. Enter Supabase connection details
3. Drag `gold_salary_trends` to canvas
4. Create calculated fields for date parsing:
   ```
   Date: DATE(STR([salary_date_sk]))
   ```
5. Build visualizations (line charts for trends, bar charts for comparisons)

### Power BI

1. Get Data → PostgreSQL database
2. Enter Supabase connection details
3. Load `gold_*` tables
4. Create relationships (if needed)
5. Build visuals (salary trends, skill demand, hiring velocity)

### Looker / Metabase / Superset

Same connection pattern:
1. Add Postgres database connection
2. Point to Supabase endpoint
3. Use `lmip_consumer` credentials
4. Build dashboards from `gold_*` tables

---

## Best Practices

### Data Freshness

* Always filter on date columns to avoid stale data
* Check `created_at` column to verify last refresh
* Use `observation_count >= 5` for statistical validity

### Query Performance

* Filter on date ranges (e.g., last 30 days, last quarter)
* Use rollup levels (NULL dims) for high-level summaries
* Limit result sets to <10K rows for interactive dashboards
* Index on common filters (Supabase auto-indexes primary keys)

### Statistical Validity

* Always check `observation_count` column
* Minimum recommended: `observation_count >= 5` for percentiles
* For rare combinations (sector + role + location), use higher-level rollups

---

## Troubleshooting

### Issue: Connection Timeout

**Symptom**: Postgres connection fails with timeout error

**Resolution**:
* Verify network connectivity to Supabase endpoint
* Check firewall rules (allow outbound 5432)
* Use `sslmode=require` in connection string

### Issue: Empty Results

**Symptom**: Query returns no rows

**Resolution**:
* Check date filter (use YYYYMMDD format: 20260607)
* Verify data freshness (may not be published yet)
* Check rollup level (use NULL for totals)

### Issue: Slow Queries

**Symptom**: Queries take >30 seconds

**Resolution**:
* Add date range filter (`salary_date_sk >= 20260501`)
* Reduce result set size (add LIMIT)
* Use rollup levels instead of detail rows
* Contact LMIP team for index optimization

---

## Support & Contact

**LMIP Team**: aaryan.shrivastav1403@gmail.com

**Documentation**: `/LMIP/docs/` in Databricks workspace

**Schema Contracts**: `/LMIP/contracts/gold/` for detailed column definitions

**Slack Channel**: #lmip-support (internal)

---

## Appendix: Full Table Schemas

For complete schema definitions including all columns, data types, and constraints, refer to:

* **Data Model Documentation**: `/LMIP/docs/Data_Model.md`
* **Contract Files**: `/LMIP/contracts/gold/*.yaml`
* **Manifest Files**: `/Volumes/workspace/publish/manifests/*.json`

---

**Document Owner**: LMIP Platform Engineering Team  
**Review Frequency**: Quarterly  
**Next Review Date**: 2026-09-07