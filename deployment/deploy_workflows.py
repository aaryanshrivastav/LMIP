"""
Deploy Workflow Definitions to Databricks Jobs

This script reads JSON workflow definitions from the workflows directory
and creates or updates corresponding Databricks Jobs using the Jobs API.

Usage:
    python deploy_workflows.py [--update] [--dry-run] [--workflow <name>]

Options:
    --update        Update existing jobs if they already exist (by name)
    --dry-run       Preview changes without actually creating jobs
    --workflow      Deploy only a specific workflow file (e.g., 'init.json')
"""

import json
import os
from pathlib import Path
from typing import Dict, List, Optional
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.jobs import Task, NotebookTask, RunIf, TaskDependency
from databricks.sdk.service.compute import Environment


class WorkflowDeployer:
    """Deploy workflow JSON definitions to Databricks Jobs"""
    
    def __init__(self, dry_run: bool = False, update_existing: bool = False):
        self.w = WorkspaceClient()
        self.dry_run = dry_run
        self.update_existing = update_existing
        self.user_email = self.w.current_user.me().user_name
        
    def get_workflow_files(self, workflow_dir: Path) -> List[Path]:
        """Find all JSON workflow definition files"""
        return list(workflow_dir.glob("*.json"))
    
    def load_workflow_definition(self, filepath: Path) -> Dict:
        """Load and parse a workflow JSON file"""
        with open(filepath, 'r') as f:
            return json.load(f)
    
    def normalize_notebook_path(self, path: str) -> str:
        """Ensure notebook path is in correct format"""
        # Remove /Workspace prefix if present
        if path.startswith("/Workspace"):
            path = path.replace("/Workspace", "")
        # Ensure it starts with /
        if not path.startswith("/"):
            path = "/" + path
        return path
    
    def find_existing_job(self, job_name: str) -> Optional[int]:
        """Find job ID by name if it exists"""
        try:
            jobs = self.w.jobs.list(name=job_name)
            for job in jobs:
                if job.settings.name == job_name:
                    return job.job_id
        except Exception as e:
            print(f"  ⚠️  Error searching for existing job: {e}")
        return None
    
    def deploy_workflow(self, workflow_file: Path) -> Dict:
        """Deploy a single workflow definition to Databricks"""
        result = {
            "file": workflow_file.name,
            "status": "unknown",
            "job_id": None,
            "job_name": None,
            "error": None
        }
        
        try:
            # Load workflow definition
            workflow = self.load_workflow_definition(workflow_file)
            job_name = workflow.get("name", workflow_file.stem)
            result["job_name"] = job_name
            
            print(f"\n📋 Processing: {job_name} ({workflow_file.name})")
            
            # Normalize notebook paths
            for task in workflow.get("tasks", []):
                if "notebook_task" in task:
                    original_path = task["notebook_task"]["notebook_path"]
                    normalized_path = self.normalize_notebook_path(original_path)
                    task["notebook_task"]["notebook_path"] = normalized_path
                    if normalized_path != original_path:
                        print(f"  📝 Normalized path: {normalized_path}")
            
            # Check if job already exists
            existing_job_id = self.find_existing_job(job_name)
            
            if existing_job_id and not self.update_existing:
                result["status"] = "skipped"
                result["job_id"] = existing_job_id
                print(f"  ⏭️  Job already exists (ID: {existing_job_id}). Use --update to modify.")
                return result
            
            if self.dry_run:
                result["status"] = "dry_run"
                print(f"  🔍 DRY RUN: Would {'update' if existing_job_id else 'create'} job")
                print(f"  📊 Tasks: {len(workflow.get('tasks', []))}")
                return result
            
            # Create or update job
            if existing_job_id and self.update_existing:
                print(f"  🔄 Updating existing job (ID: {existing_job_id})...")
                self.w.jobs.reset(job_id=existing_job_id, new_settings=workflow)
                result["status"] = "updated"
                result["job_id"] = existing_job_id
                print(f"  ✅ Updated successfully")
            else:
                print(f"  🚀 Creating new job...")
                created_job = self.w.jobs.create(**workflow)
                result["status"] = "created"
                result["job_id"] = created_job.job_id
                print(f"  ✅ Created successfully (ID: {created_job.job_id})")
            
        except FileNotFoundError:
            result["status"] = "error"
            result["error"] = f"File not found: {workflow_file}"
            print(f"  ❌ Error: {result['error']}")
        except json.JSONDecodeError as e:
            result["status"] = "error"
            result["error"] = f"Invalid JSON: {e}"
            print(f"  ❌ Error: {result['error']}")
        except Exception as e:
            result["status"] = "error"
            result["error"] = str(e)
            print(f"  ❌ Error: {result['error']}")
        
        return result
    
    def deploy_all(self, workflow_dir: Path, specific_workflow: Optional[str] = None) -> Dict:
        """Deploy all workflows or a specific workflow"""
        workflow_files = self.get_workflow_files(workflow_dir)
        
        if specific_workflow:
            workflow_files = [f for f in workflow_files if f.name == specific_workflow]
            if not workflow_files:
                print(f"❌ Workflow file not found: {specific_workflow}")
                return {"summary": {"total": 0, "error": 1}}
        
        if not workflow_files:
            print("❌ No workflow JSON files found in directory")
            return {"summary": {"total": 0}}
        
        print(f"🔍 Found {len(workflow_files)} workflow file(s)")
        
        results = []
        for workflow_file in sorted(workflow_files):
            result = self.deploy_workflow(workflow_file)
            results.append(result)
        
        # Summary
        summary = {
            "total": len(results),
            "created": sum(1 for r in results if r["status"] == "created"),
            "updated": sum(1 for r in results if r["status"] == "updated"),
            "skipped": sum(1 for r in results if r["status"] == "skipped"),
            "error": sum(1 for r in results if r["status"] == "error"),
            "dry_run": sum(1 for r in results if r["status"] == "dry_run")
        }
        
        print("\n" + "="*60)
        print("📊 DEPLOYMENT SUMMARY")
        print("="*60)
        print(f"Total workflows:  {summary['total']}")
        print(f"✅ Created:       {summary['created']}")
        print(f"🔄 Updated:       {summary['updated']}")
        print(f"⏭️  Skipped:       {summary['skipped']}")
        print(f"❌ Errors:        {summary['error']}")
        if self.dry_run:
            print(f"🔍 Dry run:       {summary['dry_run']}")
        print("="*60)
        
        return {"results": results, "summary": summary}


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(description="Deploy workflow definitions to Databricks Jobs")
    parser.add_argument("--update", action="store_true", 
                       help="Update existing jobs if they already exist")
    parser.add_argument("--dry-run", action="store_true",
                       help="Preview changes without creating/updating jobs")
    parser.add_argument("--workflow", type=str,
                       help="Deploy only a specific workflow file (e.g., 'init.json')")
    parser.add_argument("--workflow-dir", type=str, 
                       default=".",
                       help="Directory containing workflow JSON files (default: current directory)")
    
    args = parser.parse_args()
    
    # Get workflow directory
    workflow_dir = Path(args.workflow_dir).resolve()
    if not workflow_dir.exists():
        print(f"❌ Workflow directory not found: {workflow_dir}")
        return 1
    
    print(f"📁 Workflow directory: {workflow_dir}")
    
    # Create deployer and run
    deployer = WorkflowDeployer(
        dry_run=args.dry_run,
        update_existing=args.update
    )
    
    result = deployer.deploy_all(workflow_dir, args.workflow)
    
    # Exit code based on results
    if result["summary"].get("error", 0) > 0:
        return 1
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
