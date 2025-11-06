#!/usr/bin/env bash
# Setup script for Git Bash on Windows
# Fixes line endings and verifies environment

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=================================="
echo "Git Bash Setup for fundedhere-etl"
echo "=================================="
echo ""

# Detect if running in Git Bash
if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]] || [[ -n "$WINDIR" ]]; then
  echo -e "${GREEN}✓${NC} Detected Git Bash on Windows"
else
  echo -e "${YELLOW}⚠${NC} Not running on Windows - this script is for Git Bash"
fi

echo ""
echo "Step 1: Fixing line endings..."

# Fix .env file
if [ -f .env ]; then
  sed -i 's/\r$//' .env
  echo -e "${GREEN}✓${NC} Fixed .env"
else
  echo -e "${YELLOW}⚠${NC} No .env file found - will create from template"
  if [ -f .env.example ]; then
    cp .env.example .env
    sed -i 's/\r$//' .env
    # Set Git Bash compatible defaults
    cat >> .env <<'EOF'

# Git Bash on Windows defaults
DB_MODE=host
PGHOST=localhost
PGPORT=5433
PGDATABASE=appdb
PGUSER=appuser
PGPASSWORD=changeme
PGSSLMODE=disable
EOF
    echo -e "${GREEN}✓${NC} Created .env from template"
  fi
fi

# Fix all shell scripts
echo "Fixing shell script line endings..."
find scripts -name "*.sh" -type f -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo -e "${GREEN}✓${NC} Fixed all .sh files"

# Fix SQL files
echo "Fixing SQL file line endings..."
find sql initdb -name "*.sql" -type f -exec sed -i 's/\r$//' {} \; 2>/dev/null || true
echo -e "${GREEN}✓${NC} Fixed all .sql files"

# Fix Makefile
if [ -f Makefile ]; then
  sed -i 's/\r$//' Makefile
  echo -e "${GREEN}✓${NC} Fixed Makefile"
fi

echo ""
echo "Step 2: Verifying dependencies..."

# Check Docker
if command -v docker &> /dev/null; then
  echo -e "${GREEN}✓${NC} Docker found: $(docker --version | head -1)"
else
  echo -e "${RED}✗${NC} Docker not found - please install Docker Desktop for Windows"
  exit 1
fi

# Check Docker Compose
if command -v docker compose &> /dev/null || command -v docker-compose &> /dev/null; then
  echo -e "${GREEN}✓${NC} Docker Compose found"
else
  echo -e "${RED}✗${NC} Docker Compose not found"
  exit 1
fi

# Check Make
if command -v make &> /dev/null; then
  echo -e "${GREEN}✓${NC} Make found: $(make --version | head -1)"
else
  echo -e "${YELLOW}⚠${NC} Make not found - install via: winget install GnuWin32.Make"
  echo "    Or use scripts directly instead of make commands"
fi

# Check psql (optional)
if command -v psql &> /dev/null; then
  echo -e "${GREEN}✓${NC} psql found: $(psql --version)"
else
  echo -e "${YELLOW}⚠${NC} psql not found (optional) - install PostgreSQL client if needed"
fi

# Check Python (optional)
if command -v python &> /dev/null || command -v python3 &> /dev/null; then
  PYTHON_CMD=$(command -v python3 || command -v python)
  echo -e "${GREEN}✓${NC} Python found: $($PYTHON_CMD --version)"
else
  echo -e "${YELLOW}⚠${NC} Python not found (optional) - needed for some scripts"
fi

echo ""
echo "Step 3: Configuring Git..."

# Configure Git to use LF
git config core.autocrlf input 2>/dev/null || true
echo -e "${GREEN}✓${NC} Set git core.autocrlf=input (use LF)"

# Check if .gitattributes exists
if [ -f .gitattributes ]; then
  echo -e "${GREEN}✓${NC} .gitattributes found"
else
  echo -e "${YELLOW}⚠${NC} .gitattributes missing - line endings may not be enforced"
fi

echo ""
echo "Step 4: Verifying file permissions..."

# Make scripts executable
chmod +x scripts/*.sh 2>/dev/null || true
echo -e "${GREEN}✓${NC} Made scripts executable"

echo ""
echo "Step 5: Testing Docker connection..."

# Test Docker
if docker ps &> /dev/null; then
  echo -e "${GREEN}✓${NC} Docker daemon is running"
else
  echo -e "${RED}✗${NC} Docker daemon not running - start Docker Desktop"
  exit 1
fi

# Check if fundedhere postgres container exists
if docker ps -a | grep -q "app-postgres"; then
  if docker ps | grep -q "app-postgres"; then
    echo -e "${GREEN}✓${NC} PostgreSQL container is running"
  else
    echo -e "${YELLOW}⚠${NC} PostgreSQL container exists but not running - use: make up-wait"
  fi
else
  echo -e "${YELLOW}⚠${NC} PostgreSQL container not found - use: make up-wait"
fi

echo ""
echo "=================================="
echo -e "${GREEN}✓ Setup Complete!${NC}"
echo "=================================="
echo ""
echo "Next steps:"
echo "  1. Start database:        make up-wait"
echo "  2. Initialize database:   make bootstrap"
echo "  3. Load data:            make load-fast"
echo "  4. Start web interface:  make webapp-up"
echo ""
echo "Troubleshooting:"
echo "  - Connection errors: Check .env file has correct settings"
echo "  - Line ending errors: Run this script again"
echo "  - Permission errors: Run: chmod +x scripts/*.sh"
echo ""
echo "Documentation:"
echo "  - README.md"
echo "  - docs/CONNECTION_FIX.md"
echo "  - docs/GITBASH_SETUP.md"
echo ""
