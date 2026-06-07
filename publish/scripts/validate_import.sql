-- LMIP Data Import Validation Script
-- Run after loading bundle to verify data integrity
-- Version: 1.0.0

\echo ''
\echo '=== LMIP Data Import Validation Report ==='
\echo ''

-- 1. Row Counts
\echo '1. Table Row Counts:'
\echo '-------------------'
SELECT 
  'dim_sector' as table_name,
  COUNT(*) as row_count
FROM dim_sector
UNION ALL
SELECT 'dim_company', COUNT(*) FROM dim_company
UNION ALL
SELECT 'dim_location', COUNT(*) FROM dim_location
UNION ALL
SELECT 'dim_role', COUNT(*) FROM dim_role
UNION ALL
SELECT 'dim_skill', COUNT(*) FROM dim_skill
UNION ALL
SELECT 'dim_source', COUNT(*) FROM dim_source
UNION ALL
SELECT 'gold_company_hiring', COUNT(*) FROM gold_company_hiring
UNION ALL
SELECT 'gold_hospitality_companies', COUNT(*) FROM gold_hospitality_companies
UNION ALL
SELECT 'gold_salary_trends', COUNT(*) FROM gold_salary_trends
UNION ALL
SELECT 'gold_skill_demand', COUNT(*) FROM gold_skill_demand
UNION ALL
SELECT 'gold_location_trends', COUNT(*) FROM gold_location_trends
ORDER BY table_name;

\echo ''
\echo '2. Referential Integrity Checks:'
\echo '---------------------------------'

-- Check for orphaned records in gold_company_hiring
\echo '  gold_company_hiring orphans:'
SELECT 
  'Missing sector_sk' as issue,
  COUNT(*) as violation_count
FROM gold_company_hiring gch
LEFT JOIN dim_sector ds ON gch.sector_sk = ds.sector_sk
WHERE ds.sector_sk IS NULL
UNION ALL
SELECT 
  'Missing company_sk',
  COUNT(*)
FROM gold_company_hiring gch
LEFT JOIN dim_company dc ON gch.company_sk = dc.company_sk
WHERE dc.company_sk IS NULL
UNION ALL
SELECT 
  'Missing location_sk (non-NULL)',
  COUNT(*)
FROM gold_company_hiring gch
LEFT JOIN dim_location dl ON gch.location_sk = dl.location_sk
WHERE gch.location_sk IS NOT NULL AND dl.location_sk IS NULL;

-- Check for orphaned records in gold_salary_trends
\echo ''
\echo '  gold_salary_trends orphans:'
SELECT 
  'Missing sector_sk' as issue,
  COUNT(*) as violation_count
FROM gold_salary_trends gst
LEFT JOIN dim_sector ds ON gst.sector_sk = ds.sector_sk
WHERE ds.sector_sk IS NULL
UNION ALL
SELECT 
  'Missing role_sk (non-NULL)',
  COUNT(*)
FROM gold_salary_trends gst
LEFT JOIN dim_role dr ON gst.role_sk = dr.role_sk
WHERE gst.role_sk IS NOT NULL AND dr.role_sk IS NULL
UNION ALL
SELECT 
  'Missing location_sk (non-NULL)',
  COUNT(*)
FROM gold_salary_trends gst
LEFT JOIN dim_location dl ON gst.location_sk = dl.location_sk
WHERE gst.location_sk IS NOT NULL AND dl.location_sk IS NULL
UNION ALL
SELECT 
  'Missing company_sk (non-NULL)',
  COUNT(*)
FROM gold_salary_trends gst
LEFT JOIN dim_company dc ON gst.company_sk = dc.company_sk
WHERE gst.company_sk IS NOT NULL AND dc.company_sk IS NULL;

-- Check for orphaned records in gold_skill_demand
\echo ''
\echo '  gold_skill_demand orphans:'
SELECT 
  'Missing sector_sk' as issue,
  COUNT(*) as violation_count
FROM gold_skill_demand gsd
LEFT JOIN dim_sector ds ON gsd.sector_sk = ds.sector_sk
WHERE ds.sector_sk IS NULL
UNION ALL
SELECT 
  'Missing skill_sk',
  COUNT(*)
FROM gold_skill_demand gsd
LEFT JOIN dim_skill dsk ON gsd.skill_sk = dsk.skill_sk
WHERE dsk.skill_sk IS NULL
UNION ALL
SELECT 
  'Missing role_sk (non-NULL)',
  COUNT(*)
FROM gold_skill_demand gsd
LEFT JOIN dim_role dr ON gsd.role_sk = dr.role_sk
WHERE gsd.role_sk IS NOT NULL AND dr.role_sk IS NULL
UNION ALL
SELECT 
  'Missing location_sk (non-NULL)',
  COUNT(*)
FROM gold_skill_demand gsd
LEFT JOIN dim_location dl ON gsd.location_sk = dl.location_sk
WHERE gsd.location_sk IS NOT NULL AND dl.location_sk IS NULL;

\echo ''
\echo '3. NULL Constraint Checks:'
\echo '---------------------------'

-- Check for NULL primary keys
\echo '  NULL primary keys:'
SELECT 
  'dim_sector.sector_sk' as column_name,
  COUNT(*) as null_count
FROM dim_sector
WHERE sector_sk IS NULL
UNION ALL
SELECT 'dim_company.company_sk', COUNT(*) FROM dim_company WHERE company_sk IS NULL
UNION ALL
SELECT 'dim_location.location_sk', COUNT(*) FROM dim_location WHERE location_sk IS NULL
UNION ALL
SELECT 'dim_role.role_sk', COUNT(*) FROM dim_role WHERE role_sk IS NULL
UNION ALL
SELECT 'dim_skill.skill_sk', COUNT(*) FROM dim_skill WHERE skill_sk IS NULL
UNION ALL
SELECT 'dim_source.source_sk', COUNT(*) FROM dim_source WHERE source_sk IS NULL;

-- Check for NULL required columns in facts
\echo ''
\echo '  NULL required fact columns:'
SELECT 
  'gold_company_hiring.sector_sk' as column_name,
  COUNT(*) as null_count
FROM gold_company_hiring
WHERE sector_sk IS NULL OR company_sk IS NULL OR hiring_date_sk IS NULL
UNION ALL
SELECT 
  'gold_salary_trends.sector_sk',
  COUNT(*)
FROM gold_salary_trends
WHERE sector_sk IS NULL OR salary_date_sk IS NULL
UNION ALL
SELECT 
  'gold_skill_demand.skill_sk',
  COUNT(*)
FROM gold_skill_demand
WHERE sector_sk IS NULL OR skill_sk IS NULL OR demand_date_sk IS NULL;

\echo ''
\echo '4. Date Range Checks:'
\echo '---------------------'

-- Date ranges for fact tables
\echo '  Fact table date ranges:'
SELECT 
  'gold_company_hiring' as table_name,
  MIN(hiring_date_sk) as min_date,
  MAX(hiring_date_sk) as max_date,
  COUNT(DISTINCT hiring_date_sk) as distinct_dates
FROM gold_company_hiring
UNION ALL
SELECT 
  'gold_hospitality_companies',
  MIN(hospitality_date_sk),
  MAX(hospitality_date_sk),
  COUNT(DISTINCT hospitality_date_sk)
FROM gold_hospitality_companies
UNION ALL
SELECT 
  'gold_salary_trends',
  MIN(salary_date_sk),
  MAX(salary_date_sk),
  COUNT(DISTINCT salary_date_sk)
FROM gold_salary_trends
UNION ALL
SELECT 
  'gold_skill_demand',
  MIN(demand_date_sk),
  MAX(demand_date_sk),
  COUNT(DISTINCT demand_date_sk)
FROM gold_skill_demand
UNION ALL
SELECT 
  'gold_location_trends',
  MIN(location_date_sk),
  MAX(location_date_sk),
  COUNT(DISTINCT location_date_sk)
FROM gold_location_trends;

-- Check for invalid date formats (must be YYYYMMDD)
\echo ''
\echo '  Invalid date formats:'
SELECT 
  'gold_company_hiring' as table_name,
  COUNT(*) as invalid_count
FROM gold_company_hiring
WHERE hiring_date_sk < 19000101 OR hiring_date_sk > 21001231
UNION ALL
SELECT 'gold_salary_trends', COUNT(*)
FROM gold_salary_trends
WHERE salary_date_sk < 19000101 OR salary_date_sk > 21001231
UNION ALL
SELECT 'gold_skill_demand', COUNT(*)
FROM gold_skill_demand
WHERE demand_date_sk < 19000101 OR demand_date_sk > 21001231;

\echo ''
\echo '5. Data Quality Checks:'
\echo '-----------------------'

-- Check for duplicate dimension keys
\echo '  Duplicate dimension keys:'
SELECT 
  'dim_sector' as table_name,
  sector_sk,
  COUNT(*) as duplicate_count
FROM dim_sector
GROUP BY sector_sk
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dim_company', company_sk, COUNT(*)
FROM dim_company
GROUP BY company_sk
HAVING COUNT(*) > 1
UNION ALL
SELECT 'dim_location', location_sk, COUNT(*)
FROM dim_location
GROUP BY location_sk
HAVING COUNT(*) > 1;

-- Check for negative values in counts
\echo ''
\echo '  Negative count values:'
SELECT 
  'gold_company_hiring' as table_name,
  COUNT(*) as negative_count
FROM gold_company_hiring
WHERE active_jobs < 0 OR new_jobs < 0 OR closed_jobs < 0
UNION ALL
SELECT 'gold_skill_demand', COUNT(*)
FROM gold_skill_demand
WHERE mentions_count < 0 OR unique_jobs_count < 0;

\echo ''
\echo '6. Summary Statistics:'
\echo '----------------------'

-- Overall statistics
\echo '  Overall metrics:'
SELECT 
  'Total Dimension Records' as metric,
  (
    (SELECT COUNT(*) FROM dim_sector) +
    (SELECT COUNT(*) FROM dim_company) +
    (SELECT COUNT(*) FROM dim_location) +
    (SELECT COUNT(*) FROM dim_role) +
    (SELECT COUNT(*) FROM dim_skill) +
    (SELECT COUNT(*) FROM dim_source)
  ) as value
UNION ALL
SELECT 
  'Total Fact Records',
  (
    (SELECT COUNT(*) FROM gold_company_hiring) +
    (SELECT COUNT(*) FROM gold_hospitality_companies) +
    (SELECT COUNT(*) FROM gold_salary_trends) +
    (SELECT COUNT(*) FROM gold_skill_demand) +
    (SELECT COUNT(*) FROM gold_location_trends)
  );

\echo ''
\echo '=== Validation Complete ==='
\echo ''
\echo 'Check for any non-zero violation counts above.'
\echo 'All referential integrity and NULL checks should return 0.'
\echo ''
