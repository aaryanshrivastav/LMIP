#!/usr/bin/env python3
"""
LMIP Data Bundle Loader

Loads published LMIP data bundles into PostgreSQL/Supabase databases.
Supports full refresh and incremental modes.

Usage:
    python load_bundle.py --database-url $DATABASE_URL --manifest manifest.json --mode full
    python load_bundle.py --database-url $DATABASE_URL --manifest manifest.json --mode incremental
    python load_bundle.py --validate-only --manifest manifest.json
"""

import argparse
import hashlib
import json
import logging
import sys
from pathlib import Path
from typing import Dict, List, Optional

import pandas as pd
import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_batch

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('load_bundle')


class BundleLoader:
    """Loads LMIP data bundles into target databases."""
    
    def __init__(self, database_url: str, manifest_path: Path, bundle_root: Path):
        self.database_url = database_url
        self.manifest_path = manifest_path
        self.bundle_root = bundle_root
        self.manifest = self._load_manifest()
        self.conn = None
        
    def _load_manifest(self) -> Dict:
        """Load and validate manifest file."""
        logger.info(f"Loading manifest: {self.manifest_path}")
        with open(self.manifest_path, 'r') as f:
            manifest = json.load(f)
        
        # Validate required fields
        required_fields = ['manifest_version', 'publication', 'tables']
        for field in required_fields:
            if field not in manifest:
                raise ValueError(f"Manifest missing required field: {field}")
        
        logger.info(f"Manifest loaded: {manifest['publication']['bundle_id']}")
        return manifest
    
    def _calculate_checksum(self, file_path: Path) -> str:
        """Calculate SHA256 checksum of file."""
        sha256 = hashlib.sha256()
        with open(file_path, 'rb') as f:
            for block in iter(lambda: f.read(4096), b''):
                sha256.update(block)
        return sha256.hexdigest()
    
    def validate_bundle(self) -> bool:
        """Validate bundle integrity."""
        logger.info("Validating bundle integrity...")
        
        errors = []
        
        for table_info in self.manifest['tables']:
            table_name = table_info['table_name']
            file_name = table_info['file_name']
            expected_checksum = table_info.get('checksum_sha256')
            expected_rows = table_info.get('row_count')
            
            file_path = self.bundle_root / file_name
            
            # Check file exists
            if not file_path.exists():
                errors.append(f"{table_name}: File not found: {file_path}")
                continue
            
            # Validate checksum
            if expected_checksum:
                actual_checksum = self._calculate_checksum(file_path)
                if actual_checksum != expected_checksum:
                    errors.append(f"{table_name}: Checksum mismatch")
            
            # Validate row count
            if expected_rows is not None:
                df = pd.read_csv(file_path)
                actual_rows = len(df)
                if actual_rows != expected_rows:
                    errors.append(
                        f"{table_name}: Row count mismatch. "
                        f"Expected {expected_rows}, got {actual_rows}"
                    )
        
        if errors:
            logger.error("Bundle validation failed:")
            for error in errors:
                logger.error(f"  - {error}")
            return False
        
        logger.info("Bundle validation passed ✓")
        return True
    
    def connect(self):
        """Establish database connection."""
        logger.info("Connecting to database...")
        self.conn = psycopg2.connect(self.database_url)
        self.conn.autocommit = False
        logger.info("Connected ✓")
    
    def disconnect(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()
            logger.info("Disconnected")
    
    def _table_exists(self, table_name: str) -> bool:
        """Check if table exists in database."""
        with self.conn.cursor() as cur:
            cur.execute(
                "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = %s)",
                (table_name,)
            )
            return cur.fetchone()[0]
    
    def _load_table_full(self, table_info: Dict):
        """Load table in full refresh mode (truncate and reload)."""
        table_name = table_info['table_name']
        file_name = table_info['file_name']
        file_path = self.bundle_root / file_name
        
        logger.info(f"Loading {table_name} (full refresh)...")
        
        # Read CSV
        df = pd.read_csv(file_path)
        
        # Convert date columns
        for col in df.columns:
            if 'date_sk' in col.lower():
                df[col] = pd.to_numeric(df[col], errors='coerce')
        
        # Truncate table
        with self.conn.cursor() as cur:
            cur.execute(sql.SQL("TRUNCATE TABLE {} CASCADE").format(
                sql.Identifier(table_name)
            ))
        
        # Insert data in batches
        records = df.to_dict('records')
        batch_size = 1000
        
        with self.conn.cursor() as cur:
            columns = list(df.columns)
            insert_query = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
                sql.Identifier(table_name),
                sql.SQL(', ').join(map(sql.Identifier, columns)),
                sql.SQL(', ').join(sql.Placeholder() * len(columns))
            )
            
            for i in range(0, len(records), batch_size):
                batch = records[i:i + batch_size]
                values = [[rec[col] for col in columns] for rec in batch]
                execute_batch(cur, insert_query, values)
                
                if (i + batch_size) % 10000 == 0:
                    logger.info(f"  Loaded {i + batch_size:,} rows...")
        
        logger.info(f"  Loaded {len(records):,} rows ✓")
    
    def _load_table_incremental(self, table_info: Dict):
        """Load table in incremental mode (upsert/append)."""
        table_name = table_info['table_name']
        file_name = table_info['file_name']
        file_path = self.bundle_root / file_name
        table_type = table_info.get('table_type', 'fact')
        
        logger.info(f"Loading {table_name} (incremental)...")
        
        # Read CSV
        df = pd.read_csv(file_path)
        
        if table_type == 'dimension':
            # Dimensions: UPSERT based on surrogate key
            self._upsert_dimension(table_name, df, table_info)
        else:
            # Facts: INSERT new records only
            self._append_facts(table_name, df, table_info)
    
    def _upsert_dimension(self, table_name: str, df: pd.DataFrame, table_info: Dict):
        """Upsert dimension table records."""
        records = df.to_dict('records')
        columns = list(df.columns)
        
        # Find primary key (assumes *_sk column)
        pk_col = next((col for col in columns if col.endswith('_sk')), columns[0])
        
        with self.conn.cursor() as cur:
            # Build UPSERT query
            update_cols = [col for col in columns if col != pk_col]
            
            insert_query = sql.SQL(
                "INSERT INTO {} ({}) VALUES ({}) ON CONFLICT ({}) DO UPDATE SET {}"
            ).format(
                sql.Identifier(table_name),
                sql.SQL(', ').join(map(sql.Identifier, columns)),
                sql.SQL(', ').join(sql.Placeholder() * len(columns)),
                sql.Identifier(pk_col),
                sql.SQL(', ').join(
                    sql.SQL("{} = EXCLUDED.{}").format(
                        sql.Identifier(col), sql.Identifier(col)
                    ) for col in update_cols
                )
            )
            
            values = [[rec[col] for col in columns] for rec in records]
            execute_batch(cur, insert_query, values)
        
        logger.info(f"  Upserted {len(records):,} rows ✓")
    
    def _append_facts(self, table_name: str, df: pd.DataFrame, table_info: Dict):
        """Append fact table records (skip duplicates based on date range)."""
        records = df.to_dict('records')
        columns = list(df.columns)
        
        # Find date key column
        date_col = next((col for col in columns if 'date_sk' in col.lower()), None)
        
        if date_col:
            # Get max existing date
            with self.conn.cursor() as cur:
                cur.execute(
                    sql.SQL("SELECT COALESCE(MAX({}), 0) FROM {}").format(
                        sql.Identifier(date_col),
                        sql.Identifier(table_name)
                    )
                )
                max_date = cur.fetchone()[0]
            
            # Filter to only new records
            df = df[df[date_col] > max_date]
            records = df.to_dict('records')
            
            if not records:
                logger.info("  No new records to insert ✓")
                return
        
        with self.conn.cursor() as cur:
            insert_query = sql.SQL("INSERT INTO {} ({}) VALUES ({})").format(
                sql.Identifier(table_name),
                sql.SQL(', ').join(map(sql.Identifier, columns)),
                sql.SQL(', ').join(sql.Placeholder() * len(columns))
            )
            
            values = [[rec[col] for col in columns] for rec in records]
            execute_batch(cur, insert_query, values)
        
        logger.info(f"  Inserted {len(records):,} new rows ✓")
    
    def load_full(self):
        """Load bundle in full refresh mode."""
        logger.info("Starting full refresh load...")
        
        try:
            # Phase 1: Load dimensions
            dimensions = [t for t in self.manifest['tables'] if t['table_type'] == 'dimension']
            logger.info(f"Phase 1: Loading {len(dimensions)} dimension tables")
            
            for table_info in dimensions:
                self._load_table_full(table_info)
            
            # Phase 2: Load facts
            facts = [t for t in self.manifest['tables'] if t['table_type'] == 'fact']
            logger.info(f"Phase 2: Loading {len(facts)} fact tables")
            
            for table_info in facts:
                self._load_table_full(table_info)
            
            # Commit transaction
            self.conn.commit()
            logger.info("Full refresh completed successfully ✓")
            
        except Exception as e:
            logger.error(f"Load failed: {e}")
            self.conn.rollback()
            raise
    
    def load_incremental(self):
        """Load bundle in incremental mode."""
        logger.info("Starting incremental load...")
        
        if not self.manifest['data_period'].get('is_incremental', False):
            logger.warning("Manifest indicates full refresh, not incremental")
        
        try:
            # Phase 1: Load dimensions (upsert)
            dimensions = [t for t in self.manifest['tables'] if t['table_type'] == 'dimension']
            logger.info(f"Phase 1: Upserting {len(dimensions)} dimension tables")
            
            for table_info in dimensions:
                self._load_table_incremental(table_info)
            
            # Phase 2: Load facts (append)
            facts = [t for t in self.manifest['tables'] if t['table_type'] == 'fact']
            logger.info(f"Phase 2: Appending {len(facts)} fact tables")
            
            for table_info in facts:
                self._load_table_incremental(table_info)
            
            # Commit transaction
            self.conn.commit()
            logger.info("Incremental load completed successfully ✓")
            
        except Exception as e:
            logger.error(f"Load failed: {e}")
            self.conn.rollback()
            raise


def main():
    parser = argparse.ArgumentParser(description='Load LMIP data bundle')
    parser.add_argument('--database-url', help='PostgreSQL connection URL')
    parser.add_argument('--manifest', required=True, help='Path to manifest.json')
    parser.add_argument('--mode', choices=['full', 'incremental'], help='Load mode')
    parser.add_argument('--validate-only', action='store_true', help='Only validate bundle')
    parser.add_argument('--validate-incremental', action='store_true', help='Validate incremental compatibility')
    
    args = parser.parse_args()
    
    manifest_path = Path(args.manifest)
    bundle_root = manifest_path.parent
    
    if args.validate_only:
        loader = BundleLoader('', manifest_path, bundle_root)
        valid = loader.validate_bundle()
        sys.exit(0 if valid else 1)
    
    if not args.database_url:
        logger.error("--database-url required for loading")
        sys.exit(1)
    
    if not args.mode:
        logger.error("--mode required for loading")
        sys.exit(1)
    
    loader = BundleLoader(args.database_url, manifest_path, bundle_root)
    
    # Validate before loading
    if not loader.validate_bundle():
        logger.error("Bundle validation failed, aborting load")
        sys.exit(1)
    
    try:
        loader.connect()
        
        if args.mode == 'full':
            loader.load_full()
        else:
            loader.load_incremental()
        
    except Exception as e:
        logger.error(f"Load failed: {e}")
        sys.exit(1)
    finally:
        loader.disconnect()
    
    logger.info("Done!")


if __name__ == '__main__':
    main()
