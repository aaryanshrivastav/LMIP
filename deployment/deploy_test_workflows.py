#!/usr/bin/env python3
"""
Deploy test workflows for LMIP.

This script creates Databricks jobs that run pytest test suites
for notebooks and workflows. Useful for CI/CD and automated testing.

Usage:
    python deploy_test_workflows.py --env dev
    python deploy_test_workflows.py --env prod --dry-run
"""

import os
import sys
import json
import argparse
from pathlib import Path
from databricks.sdk import WorkspaceClient
from databricks.sdk.service.jobs import Task, NotebookTask, Source, PythonWheelTask, TaskDependency


# Test workflow configurations
TEST_WORKFLOWS = {
    "LMIP_Test_Unit_Tests": {
        "description": "Run LMIP unit tests (logic tests)",
        "tests": [
            "tests/test_cdc_hash_logic.py",
            "tests/test_identity_matching.py",
            "tests/test_sector_assignment.py",
            "tests/test_quarantine_routing.py",
            "tests/test_scd2_key_generation.py",
            "tests/test_export_bundle_manifest.py",
        ],
        "tags": {"env": "test", "type": "unit"},
    },
    "LMIP_Test_Notebook_Integration": {
        "description": "Run LMIP notebook integration tests",
        "tests": [
            "tests/notebooks/test_bronze_notebooks.py",
            "tests/notebooks/test_silver_notebooks.py",
            "tests/notebooks/test_intermediate_notebooks.py",
            "tests/notebooks/test_warehouse_notebooks.py",
            "tests/notebooks/test_init_notebooks.py",
            "tests/notebooks/test_publish_notebooks.py",
        ],
        "tags": {"env": "test", "type": "integration"},
    },
    "LMIP_Test_Workflow_Integration": {
        "description": "Run LMIP workflow integration tests",
        "tests": [
            "tests/workflows/test_workflows_integration.py",
        ],
        "tags": {"env": "test", "type": "workflow"},
    },
}


def get_workspace_path(relative_path: str) -> str:
    """Convert relative path to absolute workspace path."""
    base_path = "/Workspace/Users/aaryan.shrivastav1403@gmail.com/LMIP"
    return f"{base_path}/{relative_path}"


def create_pytest_task(
    task_key: str,
    test_file: str,
    cluster_key: str,
    depends_on: list[str] = None
) -> Task:
    """Create a task that runs pytest on a test file."""
    
    workspace_path = get_workspace_path(test_file)
    
    # Use python_wheel_task to run pytest
    # Alternatively, use notebook_task if tests are in notebooks
    task = Task(
        task_key=task_key,
        description=f"Run pytest on {test_file}",
        python_wheel_task=PythonWheelTask(
            package_name="pytest",
            entry_point="pytest",
            parameters=[
                workspace_path,
                "-v",
                "--tb=short",
                "--junit-xml=/tmp/test-results.xml",
            ],
        ),
        existing_cluster_id=cluster_key,
        timeout_seconds=3600,  # 1 hour timeout
    )
    
    if depends_on:
        task.depends_on = [TaskDependency(task_key=dep) for dep in depends_on]
    
    return task


def create_test_workflow_config(
    workflow_name: str,
    workflow_config: dict,
    cluster_id: str,
    env: str
) -> dict:
    """Create job configuration for a test workflow."""
    
    tasks = []
    
    # Create a task for each test file
    for i, test_file in enumerate(workflow_config["tests"]):
        # Generate task key from test file name
        test_name = Path(test_file).stem
        task_key = f"test_{test_name}"
        
        task = create_pytest_task(
            task_key=task_key,
            test_file=test_file,
            cluster_key=cluster_id,
        )
        
        tasks.append(task)
    
    # Build job configuration
    job_config = {
        "name": f"{workflow_name}_{env.upper()}",
        "description": workflow_config["description"],
        "tags": workflow_config["tags"],
        "tasks": [t.as_dict() for t in tasks],
        "max_concurrent_runs": 1,
        "timeout_seconds": 7200,  # 2 hours
        "email_notifications": {
            "on_failure": [os.getenv("NOTIFICATION_EMAIL", "")],
        },
    }
    
    return job_config


def deploy_test_workflow(
    w: WorkspaceClient,
    workflow_name: str,
    workflow_config: dict,
    cluster_id: str,
    env: str,
    dry_run: bool = False
) -> dict:
    """Deploy a single test workflow."""
    
    print(f"\n{'[DRY RUN] ' if dry_run else ''}Deploying {workflow_name}...")
    
    # Create job configuration
    job_config = create_test_workflow_config(
        workflow_name=workflow_name,
        workflow_config=workflow_config,
        cluster_id=cluster_id,
        env=env
    )
    
    if dry_run:
        print(f"Job config: {json.dumps(job_config, indent=2)}")
        return {"job_id": None, "workflow_name": workflow_name, "dry_run": True}
    
    # Check if job already exists
    job_name = job_config["name"]
    existing_jobs = w.jobs.list(name=job_name)
    
    try:
        existing_job = next(existing_jobs)
        print(f"  Updating existing job (ID: {existing_job.job_id})...")
        
        # Update job
        w.jobs.update(
            job_id=existing_job.job_id,
            new_settings=job_config
        )
        
        job_id = existing_job.job_id
        print(f"  ✓ Updated job {job_id}")
        
    except StopIteration:
        print(f"  Creating new job...")
        
        # Create job
        job = w.jobs.create(**job_config)
        job_id = job.job_id
        print(f"  ✓ Created job {job_id}")
    
    return {
        "job_id": job_id,
        "workflow_name": workflow_name,
        "job_name": job_name,
    }


def get_or_create_test_cluster(w: WorkspaceClient, env: str) -> str:
    """Get or create a cluster for running tests."""
    
    cluster_name = f"LMIP_Test_Cluster_{env.upper()}"
    
    # Check if cluster exists
    clusters = w.clusters.list()
    for cluster in clusters:
        if cluster.cluster_name == cluster_name:
            print(f"Using existing cluster: {cluster.cluster_id}")
            return cluster.cluster_id
    
    print(f"Creating test cluster: {cluster_name}...")
    
    # Create cluster
    cluster = w.clusters.create(
        cluster_name=cluster_name,
        spark_version="13.3.x-scala2.12",
        node_type_id="i3.xlarge",
        num_workers=2,
        autotermination_minutes=60,
        spark_conf={
            "spark.databricks.cluster.profile": "singleNode",
        },
        custom_tags={
            "purpose": "testing",
            "env": env,
        },
    )
    
    print(f"✓ Created cluster: {cluster.cluster_id}")
    return cluster.cluster_id


def deploy_all_test_workflows(
    env: str = "dev",
    dry_run: bool = False,
    cluster_id: str = None
):
    """Deploy all test workflows."""
    
    print(f"{'[DRY RUN] ' if dry_run else ''}Deploying LMIP test workflows for environment: {env}")
    print("=" * 80)
    
    # Initialize Databricks client
    w = WorkspaceClient()
    
    # Get or create test cluster
    if cluster_id is None:
        cluster_id = get_or_create_test_cluster(w, env) if not dry_run else "dummy-cluster-id"
    
    print(f"\nUsing cluster: {cluster_id}")
    
    # Deploy each test workflow
    results = []
    for workflow_name, workflow_config in TEST_WORKFLOWS.items():
        result = deploy_test_workflow(
            w=w,
            workflow_name=workflow_name,
            workflow_config=workflow_config,
            cluster_id=cluster_id,
            env=env,
            dry_run=dry_run
        )
        results.append(result)
    
    # Summary
    print("\n" + "=" * 80)
    print("Deployment Summary:")
    print("=" * 80)
    for result in results:
        status = "[DRY RUN]" if result.get("dry_run") else "✓"
        print(f"{status} {result['workflow_name']}: Job ID {result.get('job_id', 'N/A')}")
    
    print("\n✓ All test workflows deployed successfully!")
    
    return results


def main():
    """Main entry point."""
    
    parser = argparse.ArgumentParser(
        description="Deploy LMIP test workflows to Databricks"
    )
    parser.add_argument(
        "--env",
        type=str,
        default="dev",
        choices=["dev", "staging", "prod"],
        help="Target environment (default: dev)"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print configuration without deploying"
    )
    parser.add_argument(
        "--cluster-id",
        type=str,
        help="Existing cluster ID to use (optional)"
    )
    
    args = parser.parse_args()
    
    try:
        deploy_all_test_workflows(
            env=args.env,
            dry_run=args.dry_run,
            cluster_id=args.cluster_id
        )
        return 0
    
    except Exception as e:
        print(f"\n✗ Deployment failed: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
