FROM python:3.11-slim

# Install system dependencies: make, git, PostgreSQL client
RUN apt-get update && apt-get install -y --no-install-recommends \
      make postgresql-client git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . /app

# Ensure data directories exist (so bind mounts are optional)
RUN mkdir -p data/inc_data data/pgdata

# Environment defaults
ENV PYTHON=python3

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["make", "etl-verify"]
