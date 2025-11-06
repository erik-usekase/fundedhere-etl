FROM python:3.11-slim

# Install system dependencies: make, git, PostgreSQL client, curl for uv install
RUN apt-get update && apt-get install -y --no-install-recommends \
      make postgresql-client git curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv - modern Python package manager
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

WORKDIR /app
COPY . /app

# Install Python dependencies with uv
RUN uv sync --frozen

# Ensure data directories exist (so bind mounts are optional)
RUN mkdir -p data/inc_data

# Environment defaults
ENV PYTHON=python3
ENV PATH="/app/.venv/bin:$PATH"

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["make", "etl-verify"]
