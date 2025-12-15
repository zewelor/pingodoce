# Pingo Doce CLI

A Ruby CLI application for interacting with the Pingo Doce mobile app API to fetch transaction history, track spending, and analyze shopping patterns.

## Features

- Fetch latest transactions with full product details
- View transaction history with pagination
- Spending analytics (by store, day of week, top products)
- Product price trend analysis
- Export data to CSV
- Docker-based development environment

## Requirements

- Docker and Docker Compose (recommended)
- Or: Ruby 3.3+, Bundler

## Quick Start (Docker)

1. Clone and setup:
   ```bash
   cp .env.example .env
   # Edit .env with your Pingo Doce credentials
   ```

2. Build and run:
   ```bash
   just build
   just  # Fetches latest transaction (default)
   ```

## Commands

```bash
just                    # Fetch latest transaction (default)
just fetch              # Same as above
just fetch --no-save    # Fetch without saving to database
just fetch --json       # Output as JSON

just transactions       # List transactions
just transactions --page 2 --size 20

just analytics          # Show spending analytics (last 30 days)
just analytics --days 60

just prices             # Show product price trends
just prices --product "milk"

just export             # Export data to CSV
just stats              # Show database statistics
just version            # Show version

just console            # Interactive Ruby console
just test               # Run tests
just lint               # Run linter
just lint-fix           # Auto-fix linting issues
just help               # Show CLI help
```

## CLI Usage (without Docker)

```bash
bundle install
bin/cli fetch                    # Fetch latest transaction
bin/cli transactions --page 1    # List transactions
bin/cli analytics --days 30      # Spending report
bin/cli prices                   # Price trends
bin/cli export                   # Export to CSV
bin/cli stats                    # Database statistics
bin/cli version                  # Show version
bin/cli help                     # Show help
```

## Development

```bash
# Build Docker image
just build

# Install dependencies
just install

# Run tests
just test

# Lint code
just lint
just lint-fix

# Security audit
just audit

# Interactive console
just console
```

## Project Structure

```
lib/
  pingo_doce.rb           # Main module with zeitwerk
  pingo_doce/
    version.rb            # Version constant
    configuration.rb      # Configuration object
    errors.rb             # Exception hierarchy
    client.rb             # API client
    analytics.rb          # Analytics and persistence
    cli.rb                # Thor CLI
bin/
  cli                     # Entry point
spec/                     # RSpec tests
data/                     # Transaction data (gitignored)
```

## Configuration

Environment variables (set in `.env`):

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PHONE_NUMBER` | Yes | - | Your Pingo Doce phone number |
| `PASSWORD` | Yes | - | Your Pingo Doce password |
| `DATA_DIR` | No | `./data` | Directory for storing analytics data |
| `LOG_LEVEL` | No | `info` | Logging level (debug, info, warn, error) |
| `DEBUG` | No | `false` | Enable debug mode |

## Security

- Never commit your `.env` file to version control
- Data files are stored in `data/` (gitignored)
- Credentials are loaded from environment variables

## License

MIT
