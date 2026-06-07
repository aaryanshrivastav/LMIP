-- LMIP Gold Layer Fact Tables Schema
-- PostgreSQL/Supabase Compatible
-- Version: 1.0.0
-- Dependencies: Run load_dimensions.sql first

-- Drop existing tables (use with caution)
-- DROP TABLE IF EXISTS gold_location_trends CASCADE;
-- DROP TABLE IF EXISTS gold_skill_demand CASCADE;
-- DROP TABLE IF EXISTS gold_salary_trends CASCADE;
-- DROP TABLE IF EXISTS gold_hospitality_companies CASCADE;
-- DROP TABLE IF EXISTS gold_company_hiring CASCADE;

-- gold_company_hiring
CREATE TABLE IF NOT EXISTS gold_company_hiring (
  hiring_date_sk INTEGER NOT NULL,
  sector_sk INTEGER NOT NULL REFERENCES dim_sector(sector_sk),
  company_sk INTEGER NOT NULL REFERENCES dim_company(company_sk),
  location_sk INTEGER REFERENCES dim_location(location_sk),
  active_jobs INTEGER NOT NULL DEFAULT 0,
  new_jobs INTEGER NOT NULL DEFAULT 0,
  closed_jobs INTEGER NOT NULL DEFAULT 0,
  net_change INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (hiring_date_sk, sector_sk, company_sk, COALESCE(location_sk, -1))
);

COMMENT ON TABLE gold_company_hiring IS 'Company hiring activity by date';
COMMENT ON COLUMN gold_company_hiring.hiring_date_sk IS 'Date key YYYYMMDD';
COMMENT ON COLUMN gold_company_hiring.sector_sk IS 'FK to dim_sector';
COMMENT ON COLUMN gold_company_hiring.company_sk IS 'FK to dim_company';
COMMENT ON COLUMN gold_company_hiring.location_sk IS 'FK to dim_location (NULL = all locations)';
COMMENT ON COLUMN gold_company_hiring.active_jobs IS 'Active jobs count';
COMMENT ON COLUMN gold_company_hiring.new_jobs IS 'New jobs posted';
COMMENT ON COLUMN gold_company_hiring.closed_jobs IS 'Jobs closed';
COMMENT ON COLUMN gold_company_hiring.net_change IS 'Net change in jobs';

-- gold_hospitality_companies
CREATE TABLE IF NOT EXISTS gold_hospitality_companies (
  hospitality_date_sk INTEGER NOT NULL,
  sector_sk INTEGER NOT NULL REFERENCES dim_sector(sector_sk),
  company_sk INTEGER NOT NULL REFERENCES dim_company(company_sk),
  active_jobs INTEGER NOT NULL DEFAULT 0,
  new_jobs INTEGER NOT NULL DEFAULT 0,
  closed_jobs INTEGER NOT NULL DEFAULT 0,
  net_change INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (hospitality_date_sk, sector_sk, company_sk)
);

COMMENT ON TABLE gold_hospitality_companies IS 'Hospitality sector company trends';
COMMENT ON COLUMN gold_hospitality_companies.hospitality_date_sk IS 'Date key YYYYMMDD';
COMMENT ON COLUMN gold_hospitality_companies.sector_sk IS 'FK to dim_sector (hospitality)';
COMMENT ON COLUMN gold_hospitality_companies.company_sk IS 'FK to dim_company';
COMMENT ON COLUMN gold_hospitality_companies.active_jobs IS 'Active jobs';
COMMENT ON COLUMN gold_hospitality_companies.new_jobs IS 'New jobs posted';
COMMENT ON COLUMN gold_hospitality_companies.closed_jobs IS 'Jobs closed';
COMMENT ON COLUMN gold_hospitality_companies.net_change IS 'Net change';

-- gold_salary_trends
CREATE TABLE IF NOT EXISTS gold_salary_trends (
  salary_date_sk INTEGER NOT NULL,
  sector_sk INTEGER NOT NULL REFERENCES dim_sector(sector_sk),
  role_sk INTEGER REFERENCES dim_role(role_sk),
  location_sk INTEGER REFERENCES dim_location(location_sk),
  company_sk INTEGER REFERENCES dim_company(company_sk),
  salary_min_median DECIMAL(12, 2),
  salary_max_median DECIMAL(12, 2),
  salary_min_p25 DECIMAL(12, 2),
  salary_max_p75 DECIMAL(12, 2),
  observation_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (salary_date_sk, sector_sk, COALESCE(role_sk, -1), COALESCE(location_sk, -1), COALESCE(company_sk, -1))
);

COMMENT ON TABLE gold_salary_trends IS 'Salary trends by sector, role, location, and company';
COMMENT ON COLUMN gold_salary_trends.salary_date_sk IS 'Date key YYYYMMDD';
COMMENT ON COLUMN gold_salary_trends.sector_sk IS 'FK to dim_sector';
COMMENT ON COLUMN gold_salary_trends.role_sk IS 'FK to dim_role (NULL = all roles)';
COMMENT ON COLUMN gold_salary_trends.location_sk IS 'FK to dim_location (NULL = all locations)';
COMMENT ON COLUMN gold_salary_trends.company_sk IS 'FK to dim_company (NULL = all companies)';
COMMENT ON COLUMN gold_salary_trends.salary_min_median IS 'Median minimum salary';
COMMENT ON COLUMN gold_salary_trends.salary_max_median IS 'Median maximum salary';
COMMENT ON COLUMN gold_salary_trends.salary_min_p25 IS '25th percentile min salary';
COMMENT ON COLUMN gold_salary_trends.salary_max_p75 IS '75th percentile max salary';
COMMENT ON COLUMN gold_salary_trends.observation_count IS 'Number of observations';

-- gold_skill_demand
CREATE TABLE IF NOT EXISTS gold_skill_demand (
  demand_date_sk INTEGER NOT NULL,
  sector_sk INTEGER NOT NULL REFERENCES dim_sector(sector_sk),
  role_sk INTEGER REFERENCES dim_role(role_sk),
  location_sk INTEGER REFERENCES dim_location(location_sk),
  skill_sk INTEGER NOT NULL REFERENCES dim_skill(skill_sk),
  mentions_count INTEGER NOT NULL DEFAULT 0,
  unique_jobs_count INTEGER NOT NULL DEFAULT 0,
  avg_confidence DECIMAL(5, 3),
  delta_vs_prev_period INTEGER,
  PRIMARY KEY (demand_date_sk, sector_sk, COALESCE(role_sk, -1), COALESCE(location_sk, -1), skill_sk)
);

COMMENT ON TABLE gold_skill_demand IS 'Skill demand by sector, role, and location';
COMMENT ON COLUMN gold_skill_demand.demand_date_sk IS 'Date key YYYYMMDD';
COMMENT ON COLUMN gold_skill_demand.sector_sk IS 'FK to dim_sector';
COMMENT ON COLUMN gold_skill_demand.role_sk IS 'FK to dim_role (NULL = all roles)';
COMMENT ON COLUMN gold_skill_demand.location_sk IS 'FK to dim_location (NULL = all locations)';
COMMENT ON COLUMN gold_skill_demand.skill_sk IS 'FK to dim_skill';
COMMENT ON COLUMN gold_skill_demand.mentions_count IS 'Times skill was mentioned';
COMMENT ON COLUMN gold_skill_demand.unique_jobs_count IS 'Unique jobs requiring skill';
COMMENT ON COLUMN gold_skill_demand.avg_confidence IS 'Average confidence score';
COMMENT ON COLUMN gold_skill_demand.delta_vs_prev_period IS 'Change vs previous period';

-- gold_location_trends
CREATE TABLE IF NOT EXISTS gold_location_trends (
  location_date_sk INTEGER NOT NULL,
  sector_sk INTEGER NOT NULL REFERENCES dim_sector(sector_sk),
  location_sk INTEGER NOT NULL REFERENCES dim_location(location_sk),
  active_jobs INTEGER NOT NULL DEFAULT 0,
  new_jobs INTEGER NOT NULL DEFAULT 0,
  unique_companies INTEGER NOT NULL DEFAULT 0,
  unique_roles INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (location_date_sk, sector_sk, location_sk)
);

COMMENT ON TABLE gold_location_trends IS 'Location-based job market trends';
COMMENT ON COLUMN gold_location_trends.location_date_sk IS 'Date key YYYYMMDD';
COMMENT ON COLUMN gold_location_trends.sector_sk IS 'FK to dim_sector';
COMMENT ON COLUMN gold_location_trends.location_sk IS 'FK to dim_location';
COMMENT ON COLUMN gold_location_trends.active_jobs IS 'Active jobs count';
COMMENT ON COLUMN gold_location_trends.new_jobs IS 'New jobs posted';
COMMENT ON COLUMN gold_location_trends.unique_companies IS 'Unique companies hiring';
COMMENT ON COLUMN gold_location_trends.unique_roles IS 'Unique roles available';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_company_hiring_date ON gold_company_hiring(hiring_date_sk);
CREATE INDEX IF NOT EXISTS idx_company_hiring_company ON gold_company_hiring(company_sk);
CREATE INDEX IF NOT EXISTS idx_company_hiring_sector ON gold_company_hiring(sector_sk);

CREATE INDEX IF NOT EXISTS idx_hospitality_date ON gold_hospitality_companies(hospitality_date_sk);
CREATE INDEX IF NOT EXISTS idx_hospitality_company ON gold_hospitality_companies(company_sk);

CREATE INDEX IF NOT EXISTS idx_salary_date ON gold_salary_trends(salary_date_sk);
CREATE INDEX IF NOT EXISTS idx_salary_sector ON gold_salary_trends(sector_sk);
CREATE INDEX IF NOT EXISTS idx_salary_role ON gold_salary_trends(role_sk);

CREATE INDEX IF NOT EXISTS idx_skill_demand_date ON gold_skill_demand(demand_date_sk);
CREATE INDEX IF NOT EXISTS idx_skill_demand_skill ON gold_skill_demand(skill_sk);
CREATE INDEX IF NOT EXISTS idx_skill_demand_sector ON gold_skill_demand(sector_sk);

CREATE INDEX IF NOT EXISTS idx_location_trends_date ON gold_location_trends(location_date_sk);
CREATE INDEX IF NOT EXISTS idx_location_trends_location ON gold_location_trends(location_sk);
CREATE INDEX IF NOT EXISTS idx_location_trends_sector ON gold_location_trends(sector_sk);

-- Version history tracking table
CREATE TABLE IF NOT EXISTS version_history (
  version_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bundle_version VARCHAR(20) NOT NULL UNIQUE,
  bundle_id VARCHAR(100) NOT NULL,
  published_at TIMESTAMPTZ NOT NULL,
  data_start_date INT NOT NULL,
  data_end_date INT NOT NULL,
  is_incremental BOOLEAN NOT NULL,
  parent_version VARCHAR(20),
  row_counts JSONB NOT NULL,
  file_checksums JSONB NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  deprecated_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON TABLE version_history IS 'Tracks published data bundle versions';
CREATE INDEX IF NOT EXISTS idx_version_history_status ON version_history(status);
CREATE INDEX IF NOT EXISTS idx_version_history_published ON version_history(published_at);
