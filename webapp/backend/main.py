"""FastAPI backend for fundedhere-etl web query interface."""
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import HTMLResponse
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import yaml
import subprocess
import os
from pathlib import Path
from datetime import datetime

from db import execute_query, get_db_health

app = FastAPI(title="FundedHere ETL Query Interface")

# CORS - localhost-only trust
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:8080", "http://127.0.0.1:8080"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load predefined queries
QUERIES_FILE = Path(__file__).parent / "queries.yaml"
PREDEFINED_QUERIES = {}

if QUERIES_FILE.exists():
    with open(QUERIES_FILE) as f:
        PREDEFINED_QUERIES = yaml.safe_load(f) or {}


class QueryRequest(BaseModel):
    sql: str
    limit: Optional[int] = 1000


class QueryResponse(BaseModel):
    columns: List[str]
    rows: List[Dict[str, Any]]
    row_count: int


@app.get("/api/health")
async def health_check():
    """Check API and database health."""
    db_status = get_db_health()
    return {
        "status": "healthy" if db_status["connected"] else "unhealthy",
        "database": db_status
    }


@app.get("/api/queries/predefined")
async def list_predefined_queries():
    """List all available predefined queries."""
    return {
        "queries": [
            {
                "id": qid,
                "name": q.get("name", qid),
                "description": q.get("description", ""),
                "category": q.get("category", "general")
            }
            for qid, q in PREDEFINED_QUERIES.items()
        ]
    }


@app.get("/api/queries/predefined/{query_id}")
async def get_predefined_query(query_id: str):
    """Get details of a specific predefined query."""
    if query_id not in PREDEFINED_QUERIES:
        raise HTTPException(status_code=404, detail=f"Query {query_id} not found")

    query = PREDEFINED_QUERIES[query_id]
    return {
        "id": query_id,
        "name": query.get("name", query_id),
        "description": query.get("description", ""),
        "sql": query.get("sql", ""),
        "category": query.get("category", "general")
    }


@app.post("/api/queries/execute", response_model=QueryResponse)
async def execute_custom_query(request: QueryRequest):
    """Execute a custom SQL query (read-only)."""
    sql = request.sql.strip()

    # Security: only allow SELECT queries
    if not sql.upper().startswith("SELECT"):
        raise HTTPException(
            status_code=400,
            detail="Only SELECT queries are allowed"
        )

    # Apply limit
    if request.limit and "LIMIT" not in sql.upper():
        sql = f"{sql} LIMIT {request.limit}"

    try:
        result = execute_query(sql)
        return QueryResponse(
            columns=result["columns"],
            rows=result["rows"],
            row_count=len(result["rows"])
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")


@app.get("/api/queries/predefined/{query_id}/execute", response_model=QueryResponse)
async def execute_predefined_query(
    query_id: str,
    limit: Optional[int] = Query(None, ge=1, le=10000)
):
    """Execute a predefined query."""
    if query_id not in PREDEFINED_QUERIES:
        raise HTTPException(status_code=404, detail=f"Query {query_id} not found")

    query = PREDEFINED_QUERIES[query_id]
    sql = query.get("sql", "")

    if not sql:
        raise HTTPException(status_code=400, detail="Query has no SQL defined")

    # Apply limit if specified
    if limit and "LIMIT" not in sql.upper():
        sql = f"{sql} LIMIT {limit}"

    try:
        result = execute_query(sql)
        return QueryResponse(
            columns=result["columns"],
            rows=result["rows"],
            row_count=len(result["rows"])
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")


@app.get("/api/views/{view_name}", response_model=QueryResponse)
async def query_view(
    view_name: str,
    limit: Optional[int] = Query(10, ge=1, le=10000),
    offset: Optional[int] = Query(0, ge=0)
):
    """Query a specific view (sheet1/level1, sheet2a/level2a, sheet2b/level2b)."""
    view_map = {
        "sheet1": "mart.v_level1",
        "level1": "mart.v_level1",
        "sheet2a": "mart.v_level2a",
        "level2a": "mart.v_level2a",
        "sheet2b": "mart.v_level2b",
        "level2b": "mart.v_level2b",
    }

    db_view = view_map.get(view_name.lower())
    if not db_view:
        raise HTTPException(
            status_code=404,
            detail=f"View {view_name} not found. Available: {', '.join(view_map.keys())}"
        )

    sql = f"SELECT * FROM {db_view} LIMIT {limit} OFFSET {offset}"

    try:
        result = execute_query(sql)
        return QueryResponse(
            columns=result["columns"],
            rows=result["rows"],
            row_count=len(result["rows"])
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Query failed: {str(e)}")


@app.post("/api/etl/reload")
async def reload_etl():
    """
    Trigger ETL reload process.
    Reloads CSV data, regenerates mappings, and refreshes views.
    """
    try:
        # Run ETL reload script
        # The script should be accessible from the container
        result = subprocess.run(
            ["make", "etl-reload"],
            cwd="/app",
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        )

        if result.returncode == 0:
            return {
                "status": "success",
                "message": "ETL reload completed successfully",
                "timestamp": datetime.now().isoformat(),
                "output": result.stdout
            }
        else:
            raise HTTPException(
                status_code=500,
                detail=f"ETL reload failed: {result.stderr}"
            )
    except subprocess.TimeoutExpired:
        raise HTTPException(
            status_code=408,
            detail="ETL reload timed out (exceeded 5 minutes)"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"ETL reload error: {str(e)}"
        )


@app.get("/api/etl/status")
async def etl_status():
    """
    Get ETL system status: row counts, periods loaded, last refresh time.
    """
    try:
        # Get row counts
        counts_query = """
SELECT
    'external_accounts' AS table_name,
    COUNT(*) AS row_count
FROM raw.external_accounts
UNION ALL
SELECT 'va_txn', COUNT(*) FROM raw.va_txn
UNION ALL
SELECT 'repmt_sku', COUNT(*) FROM raw.repmt_sku
UNION ALL
SELECT 'repmt_sales', COUNT(*) FROM raw.repmt_sales
"""
        counts = execute_query(counts_query)

        # Get available periods
        periods_query = "SELECT * FROM mart.v_available_periods"
        periods = execute_query(periods_query)

        # Get last refresh time
        refresh_query = """
SELECT matviewname, last_refresh
FROM pg_matviews
WHERE schemaname = 'core'
ORDER BY last_refresh DESC NULLS LAST
LIMIT 1
"""
        refresh_info = execute_query(refresh_query)

        return {
            "status": "healthy",
            "row_counts": counts["rows"],
            "periods": periods["rows"],
            "last_refresh": refresh_info["rows"][0] if refresh_info["rows"] else None,
            "timestamp": datetime.now().isoformat()
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Status check failed: {str(e)}")


# Serve static frontend files
app.mount("/", StaticFiles(directory="/app/frontend", html=True), name="frontend")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
