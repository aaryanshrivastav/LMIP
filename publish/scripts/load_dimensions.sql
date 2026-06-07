-- LMIP Dimension Tables Schema
-- PostgreSQL/Supabase Compatible
-- Version: 1.0.0

-- Drop existing tables (use with caution)
-- DROP TABLE IF EXISTS dim_source CASCADE;
-- DROP TABLE IF EXISTS dim_skill CASCADE;
-- DROP TABLE IF EXISTS dim_role CASCADE;
-- DROP TABLE IF EXISTS dim_location CASCADE;
-- DROP TABLE IF EXISTS dim_company CASCADE;
-- DROP TABLE IF EXISTS dim_sector CASCADE;

-- dim_sector
CREATE TABLE IF NOT EXISTS dim_sector (
  sector_sk INTEGER PRIMARY KEY,
  sector_name VARCHAR(100) NOT NULL,
  sector_family VARCHAR(100),
  sector_aliases TEXT,
  active_flag BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT uq_sector_name UNIQUE (sector_name)
);

COMMENT ON TABLE dim_sector IS 'Industry sector dimension';
COMMENT ON COLUMN dim_sector.sector_sk IS 'Surrogate key';
COMMENT ON COLUMN dim_sector.sector_name IS 'Canonical sector name';
COMMENT ON COLUMN dim_sector.sector_family IS 'Sector family/grouping';
COMMENT ON COLUMN dim_sector.sector_aliases IS 'List of aliases';
COMMENT ON COLUMN dim_sector.active_flag IS 'Is sector active';

-- dim_company
CREATE TABLE IF NOT EXISTS dim_company (
  company_sk INTEGER PRIMARY KEY,
  canonical_company_name VARCHAR(200) NOT NULL,
  company_nk VARCHAR(100) NOT NULL,
  industry VARCHAR(100),
  active_flag BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT uq_company_nk UNIQUE (company_nk)
);

COMMENT ON TABLE dim_company IS 'Company dimension';
COMMENT ON COLUMN dim_company.company_sk IS 'Surrogate key';
COMMENT ON COLUMN dim_company.canonical_company_name IS 'Standardized company name';
COMMENT ON COLUMN dim_company.company_nk IS 'Natural key';
COMMENT ON COLUMN dim_company.industry IS 'Company industry';
COMMENT ON COLUMN dim_company.active_flag IS 'Is company active';

-- dim_location
CREATE TABLE IF NOT EXISTS dim_location (
  location_sk INTEGER PRIMARY KEY,
  location_nk VARCHAR(200) NOT NULL,
  location_name VARCHAR(200) NOT NULL,
  city VARCHAR(100),
  state VARCHAR(100),
  country VARCHAR(100) NOT NULL,
  region VARCHAR(100),
  iso_country_code VARCHAR(3),
  iso_region_code VARCHAR(10),
  latitude DECIMAL(10, 7),
  longitude DECIMAL(10, 7),
  active_flag BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT uq_location_nk UNIQUE (location_nk)
);

COMMENT ON TABLE dim_location IS 'Geographic location dimension';
COMMENT ON COLUMN dim_location.location_sk IS 'Surrogate key';
COMMENT ON COLUMN dim_location.location_nk IS 'Natural key (composite)';
COMMENT ON COLUMN dim_location.location_name IS 'Full location name';
COMMENT ON COLUMN dim_location.city IS 'City name';
COMMENT ON COLUMN dim_location.state IS 'State/province';
COMMENT ON COLUMN dim_location.country IS 'Country name';
COMMENT ON COLUMN dim_location.region IS 'Geographic region';
COMMENT ON COLUMN dim_location.iso_country_code IS 'ISO 3166-1 country code';
COMMENT ON COLUMN dim_location.iso_region_code IS 'ISO 3166-2 region code';
COMMENT ON COLUMN dim_location.latitude IS 'Latitude coordinate';
COMMENT ON COLUMN dim_location.longitude IS 'Longitude coordinate';
COMMENT ON COLUMN dim_location.active_flag IS 'Is location active';

-- dim_role
CREATE TABLE IF NOT EXISTS dim_role (
  role_sk INTEGER PRIMARY KEY,
  canonical_role_id VARCHAR(100) NOT NULL,
  role_name VARCHAR(200) NOT NULL,
  role_family VARCHAR(100),
  seniority_default VARCHAR(50),
  CONSTRAINT uq_role_id UNIQUE (canonical_role_id)
);

COMMENT ON TABLE dim_role IS 'Job role dimension';
COMMENT ON COLUMN dim_role.role_sk IS 'Surrogate key';
COMMENT ON COLUMN dim_role.canonical_role_id IS 'Business key';
COMMENT ON COLUMN dim_role.role_name IS 'Canonical role name';
COMMENT ON COLUMN dim_role.role_family IS 'Role family/category';
COMMENT ON COLUMN dim_role.seniority_default IS 'Default seniority level';

-- dim_skill
CREATE TABLE IF NOT EXISTS dim_skill (
  skill_sk INTEGER PRIMARY KEY,
  canonical_skill_id VARCHAR(100) NOT NULL,
  skill_name VARCHAR(200) NOT NULL,
  skill_category VARCHAR(100),
  CONSTRAINT uq_skill_id UNIQUE (canonical_skill_id)
);

COMMENT ON TABLE dim_skill IS 'Skill dimension';
COMMENT ON COLUMN dim_skill.skill_sk IS 'Surrogate key';
COMMENT ON COLUMN dim_skill.canonical_skill_id IS 'Business key from semantic layer';
COMMENT ON COLUMN dim_skill.skill_name IS 'Canonical skill name';
COMMENT ON COLUMN dim_skill.skill_category IS 'Skill category';

-- dim_source
CREATE TABLE IF NOT EXISTS dim_source (
  source_sk INTEGER PRIMARY KEY,
  source_name VARCHAR(100) NOT NULL,
  source_endpoint VARCHAR(500),
  active_flag BOOLEAN NOT NULL DEFAULT true,
  CONSTRAINT uq_source_name UNIQUE (source_name)
);

COMMENT ON TABLE dim_source IS 'Data source dimension';
COMMENT ON COLUMN dim_source.source_sk IS 'Surrogate key';
COMMENT ON COLUMN dim_source.source_name IS 'Source identifier';
COMMENT ON COLUMN dim_source.source_endpoint IS 'API endpoint or data location';
COMMENT ON COLUMN dim_source.active_flag IS 'Is source active';

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_sector_name ON dim_sector(sector_name);
CREATE INDEX IF NOT EXISTS idx_company_name ON dim_company(canonical_company_name);
CREATE INDEX IF NOT EXISTS idx_location_country ON dim_location(country);
CREATE INDEX IF NOT EXISTS idx_location_state ON dim_location(state);
CREATE INDEX IF NOT EXISTS idx_role_name ON dim_role(role_name);
CREATE INDEX IF NOT EXISTS idx_skill_name ON dim_skill(skill_name);
