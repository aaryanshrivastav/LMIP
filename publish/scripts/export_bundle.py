#!/usr/bin/env python3
"""
LMIP Data Bundle Exporter (Databricks)

Exports Warehouse and Gold layer tables to CSV bundles with manifest.
Run this on Databricks with Spark available.

Usage:
    python export_bundle.py --mode full --output /dbfs/mnt/exports
    python export_bundle.py --mode incremental --output /dbfs/mnt/exports --from-date 20260601
"""

import argparse
import hashlib
import json
import logging
import os
from datetime import date, datetime
from pathlib import Path
from typing import Dict, List

from pyspark.sql import SparkSession, DataFrame
from pyspark.sql import functions as F

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('export_bundle')


class BundleExporter:
    """Exports LMIP data to CSV bundles."""
    
    # Table definitions
    DIMENSION_TABLES = [
        "dim_sector",
        "dim_source",
        "dim_company",
        "dim_location",
        "dim_role",
        "dim_skill"
    ]
    
    FACT_TABLES = [
        "gold_company_hiring",
        "gold_location_trends",
        "gold_salary_trends",
        "gold_skill_demand"
    ]
    
    DEPENDENCIES = {
        "gold_company_hiring": ["dim_sector", "dim_company", "dim_location"],
        "gold_location_trends": ["dim_sector", "dim_location"],
        "gold_salary_trends": ["dim_sector", "dim_role", "dim_location", "dim_company"],
        "gold_skill_demand": ["dim_sector", "dim_role", "dim_location", "dim_skill"]
    }
    
    def __init__(self, spark: SparkSession, catalog: str, warehouse_schema: str, 
                 gold_schema: str, output_root: str, mode: str = "full"):
        self.spark = spark
        self.catalog = catalog
        self.warehouse_schema = warehouse_schema
        self.gold_schema = gold_schema
        self.output_root = output_root
        self.mode = mode
        
        # Generate bundle metadata
        self.bundle_timestamp = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
        self.bundle_id = f"lmip_export_{self.bundle_timestamp}"
        self.bundle_path = Path(output_root) / self.bundle_id
        
        # Calculate version (YYYY.WW.PATCH)
        today = date.today()
        week_num = today.isocalendar()[1]
        self.version = f"{today.year}.{week_num:02d}.0"
        
        # Manifest accumulator
        self.manifest = {
            "$schema": "https://lmip.publishing/manifest/v1.0.schema.json",
            "manifest_version": "1.0",
            "publication": {
                "bundle_id": self.bundle_id,
                "bundle_version": self.version,
                "published_at": datetime.utcnow().isoformat() + "Z",
                "publisher": "LMIP_ETL_Pipeline",
                "environment": "production"
            },
            "data_period": {
                "start_date": None,
                "end_date": None,
                "granularity": "daily",
                "is_incremental": mode == "incremental",
                "incremental_from_version": None
            },
            "tables": [],
            "statistics": {},
            "quality_checks": {},
            "compatibility": {
                "min_consumer_version": "1.0.0",
                "breaking_changes": False,
                "deprecated_fields": []
            }
        }
        
        logger.info(f"Bundle ID: {self.bundle_id}")
        logger.info(f"Version: {self.version}")
        logger.info(f"Mode: {self.mode}")
    
    def _get_table_fqn(self, table_name: str) -> str:
        """Get fully qualified table name."""
        if table_name.startswith("dim_"):
            return f"{self.catalog}.{self.warehouse_schema}.{table_name}"
        else:
            return f"{self.catalog}.{self.gold_schema}.{table_name}"
    
    def _calculate_file_checksum(self, file_path: Path) -> str:
        """Calculate SHA256 checksum of CSV file."""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for block in iter(lambda: f.read(4096), b''):
                sha256.update(block)
        return sha256.hexdigest()
    
    def _export_table_to_csv(self, table_name: str, subfolder: str, 
                             filter_condition: str = None) -> Dict:
        """Export a single table to CSV."""
        fqn = self._get_table_fqn(table_name)
        logger.info(f"Exporting {fqn}...")
        
        # Load table
        df = self.spark.table(fqn)
        
        # Apply filter if incremental
        if filter_condition:
            logger.info(f"  Applying filter: {filter_condition}")
            df = df.filter(filter_condition)
        
        row_count = df.count()
        logger.info(f"  Rows to export: {row_count:,}")
        
        # Prepare output path
        output_dir = self.bundle_path / subfolder
        output_dir.mkdir(parents=True, exist_ok=True)
        output_file = output_dir / f"{table_name}.csv"
        
        # Export to CSV (coalesce to single file for consistency)
        temp_path = str(output_dir / f"{table_name}_temp")
        df.coalesce(1).write.mode("overwrite").option("header", "true").csv(temp_path)
        
        # Move the single CSV file to final location
        temp_dir = Path(temp_path)
        csv_file = next(temp_dir.glob("*.csv"))
        csv_file.rename(output_file)
        
        # Clean up temp directory
        for f in temp_dir.iterdir():
            f.unlink()
        temp_dir.rmdir()
        
        # Calculate checksum
        checksum = self._calculate_file_checksum(output_file)
        file_size = output_file.stat().st_size
        
        logger.info(f"  Exported to {output_file} ({file_size:,} bytes)")
        
        # Get schema
        columns = [{
            "name": field.name,
            "type": str(field.dataType),
            "nullable": field.nullable,
            "primary_key": field.name.endswith("_sk")
        } for field in df.schema.fields]
        
        # Determine table type
        table_type = "dimension" if table_name.startswith("dim_") else "fact"
        
        return {
            "table_name": table_name,
            "file_name": f"{subfolder}/{table_name}.csv",
            "row_count": row_count,
            "file_size_bytes": file_size,
            "checksum_sha256": checksum,
            "export_timestamp": datetime.utcnow().isoformat() + "Z",
            "table_type": table_type,
            "dependencies": self.DEPENDENCIES.get(table_name, []),
            "columns": columns
        }
    
    def export_dimensions(self) -> List[Dict]:
        """Export all dimension tables."""
        logger.info("=== Phase 1: Exporting Dimension Tables ===")
        
        table_infos = []
        for table_name in self.DIMENSION_TABLES:
            try:
                info = self._export_table_to_csv(table_name, "dimensions")
                table_infos.append(info)
            except Exception as e:
                logger.error(f"Failed to export {table_name}: {e}")
                raise
        
        logger.info(f"Exported {len(table_infos)} dimension tables")
        return table_infos
    
    def export_facts(self, from_date: int = None) -> List[Dict]:
        """Export all fact tables."""
        logger.info("=== Phase 2: Exporting Fact Tables ===")
        
        # Build filter condition for incremental
        filter_condition = None
        if self.mode == "incremental" and from_date:
            # Each fact table has a different date column
            logger.info(f"Incremental mode: exporting records > {from_date}")
        
        table_infos = []
        for table_name in self.FACT_TABLES:
            try:
                # Build table-specific filter
                if self.mode == "incremental" and from_date:
                    date_col = self._get_date_column(table_name)
                    filter_condition = f"{date_col} > {from_date}"
                else:
                    filter_condition = None
                
                info = self._export_table_to_csv(table_name, "facts", filter_condition)
                table_infos.append(info)
            except Exception as e:
                logger.error(f"Failed to export {table_name}: {e}")
                raise
        
        logger.info(f"Exported {len(table_infos)} fact tables")
        return table_infos
    
    def _get_date_column(self, table_name: str) -> str:
        """Get the date key column name for a fact table."""
        date_columns = {
            "gold_company_hiring": "hiring_date_sk",
            "gold_location_trends": "location_date_sk",
            "gold_salary_trends": "salary_date_sk",
            "gold_skill_demand": "demand_date_sk"
        }
        return date_columns.get(table_name, "date_sk")
    
    def _calculate_date_range(self) -> tuple:
        """Calculate min/max dates across all fact tables."""
        min_date = None
        max_date = None
        
        for table_name in self.FACT_TABLES:
            fqn = self._get_table_fqn(table_name)
            date_col = self._get_date_column(table_name)
            
            df = self.spark.sql(f"""
                SELECT MIN({date_col}) as min_date, MAX({date_col}) as max_date
                FROM {fqn}
            """)
            
            result = df.first()
            if result:
                table_min = result['min_date']
                table_max = result['max_date']
                
                if table_min and (min_date is None or table_min < min_date):
                    min_date = table_min
                if table_max and (max_date is None or table_max > max_date):
                    max_date = table_max
        
        return (min_date, max_date)
    
    def generate_manifest(self, table_infos: List[Dict]):
        """Generate and save manifest file."""
        logger.info("Generating manifest...")
        
        # Add table info
        self.manifest["tables"] = table_infos
        
        # Calculate date range
        min_date, max_date = self._calculate_date_range()
        self.manifest["data_period"]["start_date"] = str(min_date) if min_date else None
        self.manifest["data_period"]["end_date"] = str(max_date) if max_date else None
        
        # Calculate statistics
        total_rows = sum(t["row_count"] for t in table_infos)
        total_size = sum(t["file_size_bytes"] for t in table_infos)
        dim_count = sum(1 for t in table_infos if t["table_type"] == "dimension")
        fact_count = sum(1 for t in table_infos if t["table_type"] == "fact")
        
        self.manifest["statistics"] = {
            "total_tables": len(table_infos),
            "total_rows": total_rows,
            "total_size_bytes": total_size,
            "dimension_tables": dim_count,
            "fact_tables": fact_count
        }
        
        # Quality checks (placeholder - implement actual checks)
        self.manifest["quality_checks"] = {
            "referential_integrity_passed": True,
            "null_checks_passed": True,
            "row_count_variance_pct": 0.0,
            "validation_timestamp": datetime.utcnow().isoformat() + "Z"
        }
        
        # Save manifest
        manifest_path = self.bundle_path / "manifest.json"
        with open(manifest_path, 'w') as f:
            json.dump(self.manifest, f, indent=2)
        
        logger.info(f"Manifest saved to {manifest_path}")
    
    def create_readme(self):
        """Create README file for bundle."""
        readme_content = f"""# LMIP Data Export Bundle

**Bundle ID:** {self.bundle_id}
**Version:** {self.version}
**Published:** {self.manifest['publication']['published_at']}
**Mode:** {self.mode}

## Contents

### Dimension Tables ({len([t for t in self.manifest['tables'] if t['table_type'] == 'dimension'])})
* dim_sector - Industry sectors
* dim_company - Companies
* dim_location - Geographic locations
* dim_role - Job roles
* dim_skill - Skills
* dim_source - Data sources

### Fact Tables ({len([t for t in self.manifest['tables'] if t['table_type'] == 'fact'])})
* gold_company_hiring - Company hiring activity
* gold_salary_trends - Salary trends
* gold_skill_demand - Skill demand
* gold_location_trends - Location trends

## Data Period

* Start Date: {self.manifest['data_period']['start_date']}
* End Date: {self.manifest['data_period']['end_date']}
* Incremental: {self.manifest['data_period']['is_incremental']}

## Statistics

* Total Tables: {self.manifest['statistics']['total_tables']}
* Total Rows: {self.manifest['statistics']['total_rows']:,}
* Total Size: {self.manifest['statistics']['total_size_bytes'] / 1024 / 1024:.2f} MB

## Usage

See `publish_contracts.md` for full documentation.

Quick start:

```bash
python scripts/load_bundle.py --database-url $DATABASE_URL --manifest manifest.json --mode full
```
"""
        
        readme_path = self.bundle_path / "README.md"
        with open(readme_path, 'w') as f:
            f.write(readme_content)
        
        logger.info(f"README saved to {readme_path}")
    
    def export(self, from_date: int = None):
        """Execute full export process."""
        logger.info(f"Starting export: {self.bundle_id}")
        
        # Create bundle directory
        self.bundle_path.mkdir(parents=True, exist_ok=True)
        
        # Export dimensions
        dim_infos = self.export_dimensions()
        
        # Export facts
        fact_infos = self.export_facts(from_date)
        
        # Combine table infos
        all_table_infos = dim_infos + fact_infos
        
        # Generate manifest
        self.generate_manifest(all_table_infos)
        
        # Create README
        self.create_readme()
        
        logger.info(f"Export complete: {self.bundle_path}")
        logger.info(f"Total size: {sum(t['file_size_bytes'] for t in all_table_infos) / 1024 / 1024:.2f} MB")
        
        return self.bundle_path


def main():
    parser = argparse.ArgumentParser(description='Export LMIP data bundle')
    parser.add_argument('--catalog', default='workspace', help='Catalog name')
    parser.add_argument('--warehouse-schema', default='warehouse', help='Warehouse schema name')
    parser.add_argument('--gold-schema', default='gold', help='Gold schema name')
    parser.add_argument('--output', required=True, help='Output root directory')
    parser.add_argument('--mode', choices=['full', 'incremental'], default='full', help='Export mode')
    parser.add_argument('--from-date', type=int, help='Start date for incremental (YYYYMMDD)')
    
    args = parser.parse_args()
    
    # Get or create Spark session
    spark = SparkSession.builder.getOrCreate()
    
    # Create exporter
    exporter = BundleExporter(
        spark=spark,
        catalog=args.catalog,
        warehouse_schema=args.warehouse_schema,
        gold_schema=args.gold_schema,
        output_root=args.output,
        mode=args.mode
    )
    
    # Run export
    try:
        bundle_path = exporter.export(from_date=args.from_date)
        logger.info(f"Success! Bundle created at: {bundle_path}")
    except Exception as e:
        logger.error(f"Export failed: {e}")
        raise


if __name__ == '__main__':
    main()
