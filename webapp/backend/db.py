"""Database connection and query execution for fundedhere-etl webapp."""
import os
import psycopg2
from psycopg2.extras import RealDictCursor
from typing import Dict, List, Any


def get_db_config() -> Dict[str, str]:
    """Get database configuration from environment variables."""
    return {
        "host": os.getenv("DB_HOST", "postgres"),
        "port": os.getenv("DB_PORT", "5432"),
        "database": os.getenv("DB_NAME", "appdb"),
        "user": os.getenv("DB_USER", "appuser"),
        "password": os.getenv("DB_PASSWORD", "changeme"),
    }


def get_connection():
    """Create and return a database connection."""
    config = get_db_config()
    return psycopg2.connect(
        host=config["host"],
        port=config["port"],
        database=config["database"],
        user=config["user"],
        password=config["password"],
        cursor_factory=RealDictCursor
    )


def get_db_health() -> Dict[str, Any]:
    """Check database connection health."""
    try:
        conn = get_connection()
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            cur.fetchone()
        conn.close()
        return {
            "connected": True,
            "database": get_db_config()["database"],
            "host": get_db_config()["host"]
        }
    except Exception as e:
        return {
            "connected": False,
            "error": str(e),
            "database": get_db_config()["database"],
            "host": get_db_config()["host"]
        }


def execute_query(sql: str) -> Dict[str, Any]:
    """Execute a read-only SQL query and return results."""
    conn = get_connection()
    try:
        with conn.cursor() as cur:
            cur.execute(sql)

            # Get column names
            columns = [desc[0] for desc in cur.description] if cur.description else []

            # Fetch all rows as dicts
            rows = cur.fetchall()

            # Convert RealDictRow to regular dict and handle Decimal types
            result_rows = []
            for row in rows:
                result_row = {}
                for col in columns:
                    value = row[col]
                    # Convert Decimal to float for JSON serialization
                    if hasattr(value, '__float__'):
                        result_row[col] = float(value)
                    elif value is None:
                        result_row[col] = None
                    else:
                        result_row[col] = value
                result_rows.append(result_row)

            return {
                "columns": columns,
                "rows": result_rows
            }
    finally:
        conn.close()
