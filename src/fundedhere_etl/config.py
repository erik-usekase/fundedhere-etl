"""Configuration management with AWS RDS auto-detection"""

from typing import Literal
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    Application settings that auto-detect local vs AWS deployment.

    Local Docker:
        PGHOST=localhost, PGPORT=5433

    AWS RDS:
        PGHOST=mydb.abc123.us-east-1.rds.amazonaws.com, PGPORT=5432
    """

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",  # Allow extra env vars (webapp_port, etc)
    )

    # PostgreSQL connection
    pg_host: str = "localhost"
    pg_port: int = 5433
    pg_database: str = "appdb"
    pg_user: str = "appuser"
    pg_password: str = "changeme"
    pg_sslmode: str = "disable"

    # Data paths
    data_dir: str = "./data"

    # Runtime config
    quiet: bool = False

    @property
    def inc_data_dir(self) -> str:
        """CSV input directory"""
        return f"{self.data_dir}/inc_data"

    @property
    def is_aws(self) -> bool:
        """Auto-detect AWS RDS by hostname pattern"""
        return ".rds.amazonaws.com" in self.pg_host

    @property
    def db_mode(self) -> Literal["docker", "aws", "other"]:
        """Detected database deployment mode"""
        if self.is_aws:
            return "aws"
        if self.pg_host in ("localhost", "127.0.0.1", "postgres"):
            return "docker"
        return "other"
