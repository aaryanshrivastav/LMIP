"""
Complete LMIP Deployment Orchestrator

This script orchestrates the full deployment of the LMIP project:
0. Initialize environment (schemas, tables, metadata)
1. Deploy workspace assets (notebooks, files)
2. Deploy Databricks Jobs
3. Validate the deployment

Usage:
    python deploy_all.py [--dry-run] [--update] [--skip-validation] [--skip-init]
"""

import sys
from pathlib import Path
from rich.console import Console
from rich.panel import Panel

from config import get_config, DeploymentConfig
from deploy_workspace import WorkspaceDeployer
from deploy_jobs import JobDeployer
from validate_deployment import DeploymentValidator
from init import LMIPInitializer


console = Console()


class FullDeployer:
    """Orchestrate complete LMIP deployment"""
    
    def __init__(self, config: DeploymentConfig):
        self.config = config
        
    def print_banner(self):
        """Print deployment banner"""
        banner = """
[bold cyan]╔══════════════════════════════════════════════════════════╗
║                                                          ║
║           LMIP DEPLOYMENT ORCHESTRATOR                   ║
║                                                          ║
║  Labor Market Intelligence Platform - Full Deployment    ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝[/bold cyan]
"""
        console.print(banner)
        self.config.print_summary()
    
    def initialize_environment(self) -> bool:
        """Initialize LMIP environment: schemas, tables, and metadata"""
        console.print("\n" + "="*60)
        console.print("[bold magenta]🚀 STEP 0: Initializing Environment[/bold magenta]")
        console.print("="*60)
        
        try:
            # Get project root
            project_root = Path(__file__).parent.parent
            
            # Extract catalog from workspace_root or use default
            # workspace_root format: /Users/user@domain.com/LMIP
            catalog = "workspace"  # default
            
            initializer = LMIPInitializer(catalog=catalog, project_root=project_root)
            success = initializer.initialize()
            
            if success:
                console.print("[green]✅ Environment initialization completed successfully[/green]")
            else:
                console.print("[yellow]⚠️  Environment initialization completed with warnings[/yellow]")
            
            return success
            
        except Exception as e:
            console.print(f"[red]❌ Environment initialization failed: {e}[/red]")
            import traceback
            console.print(traceback.format_exc())
            return False
    
    def deploy_workspace(self) -> bool:
        """Deploy workspace assets"""
        console.print("\n" + "="*60)
        console.print("[bold magenta]📁 STEP 1: Deploying Workspace Assets[/bold magenta]")
        console.print("="*60)
        
        try:
            deployer = WorkspaceDeployer(self.config)
            
            # Get notebooks directory
            notebooks_dir = Path(__file__).parent.parent / "notebooks"
            if not notebooks_dir.exists():
                console.print(f"[red]❌ Notebooks directory not found: {notebooks_dir}[/red]")
                return False
            
            workspace_root = f"{self.config.workspace_root}/notebooks"
            result = deployer.deploy_directory(notebooks_dir, workspace_root)
            
            if result["summary"]["error"] > 0:
                console.print("[yellow]⚠️  Workspace deployment completed with errors[/yellow]")
                return False
            
            console.print("[green]✅ Workspace deployment completed successfully[/green]")
            return True
            
        except Exception as e:
            console.print(f"[red]❌ Workspace deployment failed: {e}[/red]")
            return False
    
    def deploy_jobs(self) -> bool:
        """Deploy Databricks Jobs"""
        console.print("\n" + "="*60)
        console.print("[bold magenta]⚙️  STEP 2: Deploying Databricks Jobs[/bold magenta]")
        console.print("="*60)
        
        try:
            deployer = JobDeployer(self.config)
            
            # Get workflows directory
            workflows_dir = Path(__file__).parent.parent / "workflows"
            if not workflows_dir.exists():
                console.print(f"[red]❌ Workflows directory not found: {workflows_dir}[/red]")
                return False
            
            result = deployer.deploy_all(workflows_dir)
            
            if result["summary"]["error"] > 0:
                console.print("[yellow]⚠️  Jobs deployment completed with errors[/yellow]")
                return False
            
            console.print("[green]✅ Jobs deployment completed successfully[/green]")
            return True
            
        except Exception as e:
            console.print(f"[red]❌ Jobs deployment failed: {e}[/red]")
            return False
    
    def validate_deployment(self) -> bool:
        """Validate the deployment"""
        console.print("\n" + "="*60)
        console.print("[bold magenta]🔍 STEP 3: Validating Deployment[/bold magenta]")
        console.print("="*60)
        
        try:
            validator = DeploymentValidator(self.config)
            result = validator.validate_all()
            
            if result["failed"] > 0:
                console.print("[yellow]⚠️  Validation completed with failures[/yellow]")
                return False
            
            console.print("[green]✅ Validation completed successfully[/green]")
            return True
            
        except Exception as e:
            console.print(f"[red]❌ Validation failed: {e}[/red]")
            return False
    
    def deploy_all(self, skip_validation: bool = False, skip_init: bool = False) -> bool:
        """Execute full deployment"""
        self.print_banner()
        
        # Track overall success
        all_success = True
        
        # Step 0: Initialize environment (unless skipped)
        if not skip_init:
            if not self.initialize_environment():
                all_success = False
                if not self.config.force_deploy:
                    console.print("\n[red]❌ Deployment aborted due to environment initialization failure[/red]")
                    return False
        else:
            console.print("\n[yellow]⚠️  Skipping environment initialization (--skip-init)[/yellow]")
        
        # Step 1: Deploy workspace assets
        if not self.deploy_workspace():
            all_success = False
            if not self.config.force_deploy:
                console.print("\n[red]❌ Deployment aborted due to workspace deployment failure[/red]")
                return False
        
        # Step 2: Deploy jobs
        if not self.deploy_jobs():
            all_success = False
            if not self.config.force_deploy:
                console.print("\n[red]❌ Deployment aborted due to jobs deployment failure[/red]")
                return False
        
        # Step 3: Validate (optional)
        if not skip_validation:
            if not self.validate_deployment():
                all_success = False
        
        # Final summary
        console.print("\n" + "="*60)
        console.print("[bold]🏁 DEPLOYMENT COMPLETE[/bold]")
        console.print("="*60)
        
        if all_success:
            console.print(Panel(
                "[bold green]🎉 All deployment steps completed successfully![/bold green]",
                border_style="green"
            ))
            console.print("\n[bold]Next Steps:[/bold]")
            console.print("  1. Configure and schedule: [cyan]LMIP_Daily_Ingestion[/cyan]")
            console.print("  2. Run your first data ingestion job")
            console.print("  3. Monitor pipeline runs in the audit tables")
            console.print("  4. Check the publish schema for consumer-ready datasets")
        else:
            console.print(Panel(
                "[bold yellow]⚠️  Deployment completed with some issues.[/bold yellow]\n"
                "Review the logs above for details.",
                border_style="yellow"
            ))
        
        console.print("="*60)
        
        return all_success


def main():
    """Main entry point"""
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Deploy complete LMIP project to Databricks",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Full deployment (init + workspace + jobs + validation)
  python deploy_all.py
  
  # Dry run to preview changes
  python deploy_all.py --dry-run
  
  # Deploy with updates to existing resources
  python deploy_all.py --update
  
  # Deploy without validation
  python deploy_all.py --skip-validation
  
  # Deploy without initialization (schemas/tables already exist)
  python deploy_all.py --skip-init
  
  # Force deploy even if errors occur
  python deploy_all.py --force
"""
    )
    parser.add_argument("--dry-run", action="store_true",
                       help="Preview changes without deploying")
    parser.add_argument("--update", action="store_true",
                       help="Update existing resources (notebooks, jobs)")
    parser.add_argument("--force", action="store_true",
                       help="Continue deployment even if errors occur")
    parser.add_argument("--skip-validation", action="store_true",
                       help="Skip validation step after deployment")
    parser.add_argument("--skip-init", action="store_true",
                       help="Skip environment initialization (schemas/tables already exist)")
    
    args = parser.parse_args()
    
    # Load configuration
    config = get_config()
    config.dry_run = args.dry_run or config.dry_run
    config.update_existing = args.update or config.update_existing
    config.force_deploy = args.force
    
    # Validate configuration
    if not config.validate():
        console.print("[red]❌ Invalid configuration. Please check your .env file.[/red]")
        return 1
    
    # Create deployer and run
    deployer = FullDeployer(config)
    success = deployer.deploy_all(
        skip_validation=args.skip_validation,
        skip_init=args.skip_init
    )
    
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
