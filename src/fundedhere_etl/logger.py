"""JSON structured logging for cloud integration"""

import json
import sys
from datetime import datetime, timezone
from typing import Any


def log(level: str, message: str, **kwargs: Any) -> None:
    """
    Output JSON structured log entry to stderr.

    Args:
        level: Log level (INFO, WARNING, ERROR)
        message: Human-readable message
        **kwargs: Additional structured fields

    Example output:
        {"timestamp": "2025-01-05T10:30:45.123Z", "level": "INFO",
         "message": "Processing CSV", "table": "va_txn", "rows": 28599}
    """
    entry = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level.upper(),
        "message": message,
        **kwargs,
    }
    print(json.dumps(entry), file=sys.stderr, flush=True)


def info(message: str, **kwargs: Any) -> None:
    """Log INFO level message"""
    log("INFO", message, **kwargs)


def warning(message: str, **kwargs: Any) -> None:
    """Log WARNING level message"""
    log("WARNING", message, **kwargs)


def error(message: str, **kwargs: Any) -> None:
    """Log ERROR level message"""
    log("ERROR", message, **kwargs)


def debug(message: str, **kwargs: Any) -> None:
    """Log DEBUG level message"""
    log("DEBUG", message, **kwargs)
