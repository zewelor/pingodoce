# Default command - fetch latest transaction
default: fetch

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

# Export to CSV
export:
    @docker compose run --rm app bin/cli export

# Show stats
stats:
    @docker compose run --rm app bin/cli stats

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
