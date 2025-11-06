"""Command-line interface for FundedHere ETL"""

import sys
import click

from . import logger
from .config import Settings
from .db import DatabaseManager
from .prep import CSVPreprocessor
from .load import CSVLoader


@click.group()
@click.version_option(version="1.0.0")
def cli():
    """
    FundedHere ETL - PostgreSQL reconciliation pipeline

    Examples:
        fundedhere-etl prep         # Prepare all CSV files
        fundedhere-etl load         # Load CSVs to database (parallel)
        fundedhere-etl bootstrap    # Initialize database schema
        fundedhere-etl refresh      # Refresh materialized views
    """
    pass


@cli.command()
@click.option(
    "--table",
    type=click.Choice(["external_accounts", "va_txn", "repmt_sku", "repmt_sales", "all"]),
    default="all",
    help="Which table to prep (default: all)",
)
def prep(table: str):
    """Prepare CSV files for loading (normalize headers)"""
    try:
        settings = Settings()
        processor = CSVPreprocessor(settings)

        if table == "all":
            results = processor.process_all()
            logger.info("All CSV files prepared", count=len(results))
        else:
            result = processor.process_table(table)
            logger.info("CSV file prepared", table=table, output=str(result))

        click.echo("✓ CSV preprocessing complete", err=True)
        sys.exit(0)

    except Exception as e:
        logger.error("CSV preprocessing failed", error=str(e))
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option(
    "--mode",
    type=click.Choice(["sequential", "parallel"]),
    default="parallel",
    help="Loading mode (default: parallel)",
)
@click.option(
    "--truncate/--no-truncate",
    default=True,
    help="Truncate tables before loading (default: yes)",
)
@click.option(
    "--workers",
    type=int,
    default=4,
    help="Number of parallel workers (default: 4)",
)
def load(mode: str, truncate: bool, workers: int):
    """Load CSV files to PostgreSQL database"""
    try:
        settings = Settings()
        db = DatabaseManager(settings)
        loader = CSVLoader(db, settings)

        if mode == "parallel":
            results = loader.load_all_parallel(truncate=truncate, max_workers=workers)
        else:
            results = loader.load_all_sequential(truncate=truncate)

        total_rows = sum(results.values())
        logger.info("Load complete", tables=len(results), total_rows=total_rows)

        click.echo(f"✓ Loaded {len(results)} tables ({total_rows:,} rows)", err=True)
        sys.exit(0)

    except Exception as e:
        logger.error("CSV load failed", error=str(e))
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
def bootstrap():
    """Initialize database schema from initdb/*.sql files"""
    try:
        settings = Settings()
        db = DatabaseManager(settings)
        db.bootstrap_schema()

        logger.info("Database schema initialized")
        click.echo("✓ Database schema initialized", err=True)
        sys.exit(0)

    except Exception as e:
        logger.error("Schema bootstrap failed", error=str(e))
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
def refresh():
    """Refresh materialized views"""
    try:
        settings = Settings()
        db = DatabaseManager(settings)
        db.refresh_materialized_views()

        logger.info("Materialized views refreshed")
        click.echo("✓ Materialized views refreshed", err=True)
        sys.exit(0)

    except Exception as e:
        logger.error("Refresh failed", error=str(e))
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
@click.option(
    "--mapping-file",
    default="sku_va_mapping.csv",
    help="Mapping CSV filename (default: sku_va_mapping.csv)",
)
def load_mapping(mapping_file: str):
    """Load SKU-VA mapping data"""
    try:
        settings = Settings()
        db = DatabaseManager(settings)
        loader = CSVLoader(db, settings)

        rows = loader.load_mapping(mapping_file)
        logger.info("Mapping loaded", rows=rows)

        click.echo(f"✓ Loaded {rows} mappings", err=True)
        sys.exit(0)

    except Exception as e:
        logger.error("Mapping load failed", error=str(e))
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


@cli.command()
def pipeline():
    """Run complete ETL pipeline (prep + bootstrap + load + refresh)"""
    try:
        settings = Settings()

        # 1. Prep CSVs
        click.echo("→ Preparing CSV files...", err=True)
        processor = CSVPreprocessor(settings)
        processor.process_all()

        # 2. Bootstrap schema (if needed)
        click.echo("→ Initializing database schema...", err=True)
        db = DatabaseManager(settings)
        db.bootstrap_schema()

        # 3. Load data
        click.echo("→ Loading CSV data (parallel)...", err=True)
        loader = CSVLoader(db, settings)
        results = loader.load_all_parallel(truncate=True)

        # 4. Load mapping
        click.echo("→ Loading SKU-VA mappings...", err=True)
        loader.load_mapping()

        # 5. Refresh views
        click.echo("→ Refreshing materialized views...", err=True)
        db.refresh_materialized_views()

        total_rows = sum(results.values())
        logger.info("Pipeline complete", tables=len(results), total_rows=total_rows)

        click.echo(f"✓ Pipeline complete ({total_rows:,} rows loaded)", err=True)
        sys.exit(0)

    except Exception as e:
        logger.error("Pipeline failed", error=str(e))
        click.echo(f"✗ Error: {e}", err=True)
        sys.exit(1)


if __name__ == "__main__":
    cli()
