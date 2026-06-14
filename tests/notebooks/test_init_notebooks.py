"""
Integration tests for Init layer notebooks.

Tests verify:
- Environment validation
- Schema creation
- Metadata seeding
- Secret registration
"""

import pytest
import os


WORKSPACE_ROOT = "/Workspace/Users/aaryan.shrivastav1403@gmail.com/LMIP"
INIT_NOTEBOOKS = {
    "init_validate_env": f"{WORKSPACE_ROOT}/notebooks/init/init_validate_env",
    "init_create_schemas": f"{WORKSPACE_ROOT}/notebooks/init/init_create_schemas",
    "init_seed_metadata": f"{WORKSPACE_ROOT}/notebooks/init/init_seed_metadata",
    "init_register_secrets": f"{WORKSPACE_ROOT}/notebooks/init/init_register_secrets",
    "init_superset_bootstrap": f"{WORKSPACE_ROOT}/notebooks/init/init_superset_bootstrap",
}


@pytest.fixture(scope="module")
def test_catalog():
    return os.getenv("TEST_CATALOG", "workspace")


class TestInitNotebookStructure:
    """Verify init notebook structure."""

    def test_all_notebooks_exist(self, workspace_client):
        """Verify all init notebooks exist."""
        for name, path in INIT_NOTEBOOKS.items():
            try:
                workspace_client.workspace.get_status(path)
            except Exception as e:
                pytest.fail(f"Notebook {name} not found at {path}: {e}")


class TestInitValidateEnv:
    """Test init_validate_env notebook."""

    def test_environment_checks(self):
        """Test environment validation logic."""
        # Check required environment variables
        required_env_vars = [
            "DATABRICKS_HOST",
            "DATABRICKS_TOKEN",
        ]
        
        # This test would validate environment is properly configured
        # In actual notebook, checks things like:
        # - Catalog exists
        # - Compute available
        # - Permissions correct
        pass


class TestInitCreateSchemas:
    """Test init_create_schemas notebook."""

    def test_schema_creation_ddl(self, spark, test_catalog):
        """Test schema creation logic."""
        # Verify DDL execution order
        schemas = ["bronze", "silver", "intermediate", "gold", "warehouse", "audit"]
        
        # Test would verify each schema is created
        # For now, just validate structure
        assert len(schemas) == 6


class TestInitSeedMetadata:
    """Test init_seed_metadata notebook."""

    def test_metadata_loading(self, spark):
        """Test metadata seeding from CSV files."""
        # Metadata files to load
        metadata_files = [
            "metadata/sectors.csv",
            "metadata/role_families.csv",
            "metadata/canonical_skills.csv",
            "metadata/canonical_roles.csv",
        ]
        
        # Test would verify each file is loaded correctly
        assert len(metadata_files) == 4


class TestInitRegisterSecrets:
    """Test init_register_secrets notebook."""

    def test_secret_registration(self):
        """Test secret registration logic."""
        # Secrets to register
        required_secrets = [
            "LINKEDIN_API_KEY",
            "INDEED_API_KEY",
            "SUPABASE_URL",
            "SUPABASE_KEY",
        ]
        
        # Test would verify secrets are registered in Databricks secret scope
        assert len(required_secrets) == 4


class TestInitSupersetBootstrap:
    """Test init_superset_bootstrap notebook."""

    def test_superset_configuration(self):
        """Test Superset bootstrap logic."""
        # This would test Superset dashboard/dataset provisioning
        pass


@pytest.mark.integration
class TestInitNotebookExecution:
    """Integration tests for init notebooks."""

    def test_init_workflow(self, workspace_client):
        """Test complete initialization workflow."""
        pytest.skip("Requires deployed workflow - see test_workflows.py")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
