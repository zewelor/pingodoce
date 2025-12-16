# Default command - fetch latest transaction
default: fetch

# First time setup: build, create db, sync all data
setup *ARGS='--pages 10':
    @echo "==> Building Docker image..."
    @docker compose build
    @echo "==> Creating database..."
    @docker compose run --rm app bin/cli db_setup
    @echo "==> Syncing transaction history (this may take a while)..."
    @docker compose run --rm app bin/cli sync {{ARGS}}
    @echo "==> Done! Run 'just stats' to see your data."

# Build Docker images
build:
    @docker compose build

# Build without cache
build-clean:
    @docker compose build --no-cache

# Fetch latest transaction (default)
fetch *ARGS:
    @docker compose run --rm app bin/cli fetch {{ARGS}}

# Sync all transactions from API
sync *ARGS:
    @docker compose run --rm app bin/cli sync {{ARGS}}

# List transactions
transactions *ARGS:
    @docker compose run --rm app bin/cli transactions {{ARGS}}

# Show analytics
analytics *ARGS:
    @docker compose run --rm app bin/cli analytics {{ARGS}}

# Show price trends
prices *ARGS:
    @docker compose run --rm app bin/cli prices {{ARGS}}

# Lookup product by barcode (EAN)
barcode EAN *ARGS:
    @docker compose run --rm app bin/cli barcode {{EAN}} {{ARGS}}

# Export to CSV
export:
    @docker compose run --rm app bin/cli export

# Show stats
stats *ARGS:
    @docker compose run --rm app bin/cli stats {{ARGS}}

# Run tests
test:
    @docker compose run --rm app bundle exec rspec

# Run linter
lint:
    @docker compose run --rm app bundle exec standardrb

# Fix linting issues
lint-fix:
    @docker compose run --rm app bundle exec standardrb --fix

# Start interactive console
console:
    @docker compose run --rm app bundle exec irb -r ./lib/pingo_doce

# Install dependencies
install:
    @docker compose run --rm app bundle install

# Show help
help:
    @docker compose run --rm app bin/cli help

# Security audit
audit:
    @docker compose run --rm app bundle exec bundle-audit check --update

# Show version
version:
    @docker compose run --rm app bin/cli version

# Database commands
# Setup database tables
db-setup:
    @docker compose run --rm app bin/cli db_setup

# Show database status
db-status:
    @docker compose run --rm app bin/cli db_status

# Import data from JSON files
db-import *ARGS:
    @docker compose run --rm app bin/cli db_import {{ARGS}}

# Show configuration
config:
    @docker compose run --rm app bin/cli config

# Health Analysis
# Show health report
health *ARGS:
    @docker compose run --rm app bin/cli health {{ARGS}}

# Generate health report as JSON (for processing)
health-json *ARGS:
    @docker compose run --rm app bin/cli health --json {{ARGS}}

# Generate raw health report (standalone script)
health-report *ARGS:
    @docker compose run --rm app bin/health_report {{ARGS}}

# Enrich all products with nutrition data
enrich-all *ARGS:
    @docker compose run --rm app bin/cli enrich_all {{ARGS}}
