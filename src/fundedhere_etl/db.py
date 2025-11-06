"""PostgreSQL database connection and operations"""

from pathlib import Path
from typing import Any
from contextlib import contextmanager
from sqlalchemy import create_engine, text, Engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.exc import OperationalError

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
        self.engine = self._create_engine()
        self.SessionLocal = sessionmaker(bind=self.engine, autoflush=False, autocommit=False)
        logger.info(
            "Database manager initialized",
            mode=settings.db_mode,
            host=settings.pg_host,
            database=settings.pg_database,
        )

    def _create_engine(self) -> Engine:
        """Create SQLAlchemy engine with connection pooling"""
        connection_url = (
            f"postgresql+psycopg://{self.settings.pg_user}:{self.settings.pg_password}"
            f"@{self.settings.pg_host}:{self.settings.pg_port}/{self.settings.pg_database}"
            f"?sslmode={self.settings.pg_sslmode}"
        )
        try:
            engine = create_engine(
                connection_url,
                pool_pre_ping=True,  # Verify connections before using
                echo=False,
            )
            logger.debug("SQLAlchemy engine created")
            return engine
        except OperationalError as e:
            logger.error(
                "Failed to create database engine",
                error=str(e),
                host=self.settings.pg_host,
            )
            raise

    @contextmanager
    def connect(self):
        """
        Create a new database connection.

        Returns:
            SQLAlchemy Connection context manager
        """
        connection = self.engine.connect()
        try:
            logger.debug("Database connection established")
            yield connection
        finally:
            connection.close()

    @contextmanager
    def session(self) -> Session:
        """
        Create a new database session.

        Returns:
            SQLAlchemy Session context manager
        """
        session = self.SessionLocal()
        try:
            yield session
        finally:
            session.close()

    def execute_sql(self, sql: str) -> None:
        """Execute SQL statement (DDL/DML)"""
        with self.connect() as conn:
            conn.execute(text(sql))
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
            result = conn.execute(text("SELECT * FROM core.refresh_all_parallel();"))
            rows = result.mappings().fetchall()
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
            result = conn.execute(text(sql))
            return [dict(row) for row in result.mappings().fetchall()]
