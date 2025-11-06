"""PostgreSQL database connection and operations"""

from pathlib import Path
from typing import Any
import psycopg
from psycopg.rows import dict_row

from . import logger
from .config import Settings


class DatabaseManager:
    """
    Manages PostgreSQL connections for local Docker or AWS RDS.

    Auto-detects deployment mode from Settings and adjusts connection
    parameters accordingly (SSL, timeouts, etc.).
    """

    def __init__(self, settings: Settings):
        self.settings = settings
        logger.info(
            "Database manager initialized",
            mode=settings.db_mode,
            host=settings.pg_host,
            database=settings.pg_database,
        )

    def get_conninfo(self) -> str:
        """Build PostgreSQL connection string"""
        return (
            f"host={self.settings.pg_host} "
            f"port={self.settings.pg_port} "
            f"dbname={self.settings.pg_database} "
            f"user={self.settings.pg_user} "
            f"password={self.settings.pg_password} "
            f"sslmode={self.settings.pg_sslmode}"
        )

    def connect(self):
        """
        Create a new database connection.

        Returns:
            psycopg.Connection with dict_row factory
        """
        try:
            conn = psycopg.connect(
                self.get_conninfo(),
                row_factory=dict_row,
            )
            logger.debug("Database connection established")
            return conn
        except psycopg.OperationalError as e:
            logger.error(
                "Failed to connect to database",
                error=str(e),
                host=self.settings.pg_host,
            )
            raise

    def execute_sql(self, sql: str) -> None:
        """Execute SQL statement (DDL/DML)"""
        with self.connect() as conn:
            conn.execute(sql)
            conn.commit()

    def execute_file(self, filepath: Path) -> None:
        """Execute SQL from file"""
        logger.info("Executing SQL file", file=str(filepath))

        try:
            sql = filepath.read_text(encoding="utf-8")
            self.execute_sql(sql)
            logger.info("SQL file executed successfully", file=str(filepath))
        except Exception as e:
            logger.error(
                "SQL file execution failed",
                file=str(filepath),
                error=str(e),
            )
            raise

    def bootstrap_schema(self) -> None:
        """
        Initialize database schema from initdb/*.sql and sql/phase2/*.sql files.

        Executes files in alphabetical order.
        Skips 000_performance_tuning.sql (requires superuser/autocommit).
        """
        # Phase 1: initdb/*.sql files
        initdb_dir = Path("initdb")
        if not initdb_dir.exists():
            logger.warning("initdb directory not found, skipping schema bootstrap")
            return

        # Skip performance tuning (requires superuser/autocommit mode)
        init_files = [
            f
            for f in sorted(initdb_dir.glob("*.sql"))
            if f.name != "000_performance_tuning.sql"
        ]

        # Phase 2: sql/phase2/*.sql files
        phase2_dir = Path("sql/phase2")
        phase2_files = sorted(phase2_dir.glob("*.sql")) if phase2_dir.exists() else []

        all_files = init_files + phase2_files
        logger.info("Starting schema bootstrap", file_count=len(all_files))

        for sql_file in all_files:
            logger.info("Executing SQL file", file=str(sql_file))
            self.execute_file(sql_file)

        logger.info("Schema bootstrap completed", file_count=len(all_files))

    def refresh_materialized_views(self) -> None:
        """Refresh all materialized views"""
        logger.info("Refreshing materialized views")
        with self.connect() as conn:
            # Use parallel refresh function for better performance
            result = conn.execute("SELECT * FROM core.refresh_all_parallel();")
            rows = result.fetchall()
            conn.commit()

            for row in rows:
                logger.debug(
                    "View refreshed",
                    view=row["view_name"],
                    duration_ms=row["duration_ms"],
                    rows=row["rows_refreshed"],
                )

        logger.info("Materialized views refreshed", view_count=len(rows))

    def query(self, sql: str) -> list[dict[str, Any]]:
        """Execute query and return results as list of dicts"""
        with self.connect() as conn:
            cursor = conn.execute(sql)
            return cursor.fetchall()
