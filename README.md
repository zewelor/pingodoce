# Pingo Doce CLI

A Ruby CLI application for interacting with the Pingo Doce mobile app API to fetch transaction history, track spending, analyze shopping patterns, and lookup product nutrition data.

## Features

- Sync full transaction history to local SQLite database
- Product enrichment with EAN, nutrition info, and ingredients
- Barcode lookup with nutrition data
- Spending analytics (by store, day of week, top products)
- Product price trend analysis
- Export data to CSV
- Docker-based development environment

## Requirements

- Docker and Docker Compose
- [just](https://github.com/casey/just) command runner (recommended)
- Pingo Doce account (Portuguese grocery store app)

## Quick Start

```bash
# 1. Setup credentials
cp .env.example .env
# Edit .env with your Pingo Doce phone number and password

# 2. Build Docker image
just build

# 3. Create database
just db-setup

# 4. Sync transaction history from API
just sync --pages 10
```

## What You Can Do

### View Statistics

```bash
just stats
```
```
Database Statistics:
  Total transactions: 100
  Total products: 513
  Total spent: 2803.86 EUR
  Date range: 2025-04-12 to 2025-12-15
```

### Spending Analytics

```bash
just analytics --days 60
```
Shows total spent, transactions count, spending by store, by day of week, and top products.

### Lookup Product by Barcode

```bash
just barcode 2000003662104
```
```
Product:
  Name: Pipocas Salgadas para Micro-Ondas Pingo Doce 90 g
  EAN: 2000003662104
  Price: 0,45 EUR
  Brand: Pingo Doce

  Nutrition (per 100g):
    Energy: 435.0 kcal
    Fat: 18.0g
    Protein: 9.8g
    Carbohydrates: 51.0g
    ...

  Ingredients:
    Milho, óleo de palma, sal (2,2%)
```

### Price Trends

```bash
just prices
```
Shows products with multiple purchases and their price changes over time.

### Export to CSV

```bash
just export
# Creates: data/transactions.csv, data/products.csv
```

## All Commands

```bash
# Data fetching
just fetch              # Fetch latest transaction
just fetch --json       # Output as JSON
just sync --pages 10    # Sync transaction history
just transactions       # List transactions

# Analytics
just stats              # Database statistics
just analytics          # Spending report (last 30 days)
just analytics --days 60
just prices             # Product price trends

# Product lookup
just barcode EAN        # Lookup product by barcode

# Database
just db-setup           # Create database tables
just db-status          # Show database status
just export             # Export to CSV

# Development
just console            # Interactive Ruby console
just test               # Run tests
just lint               # Run linter
just config             # Show configuration
```

## Direct SQLite Access

```bash
sqlite3 data/pingodoce.db
```

```sql
-- List tables
.tables

-- Total spending
SELECT SUM(total) FROM transactions;

-- Top 10 most purchased products
SELECT p.name, COUNT(*) as cnt
FROM purchases pu
JOIN products p ON pu.product_id = p.id
GROUP BY p.id ORDER BY cnt DESC LIMIT 10;

-- Products with nutrition data
SELECT p.name, n.energy_kcal, n.protein, n.carbohydrates
FROM products p
JOIN product_nutritions n ON p.id = n.product_id
WHERE n.energy_kcal IS NOT NULL LIMIT 10;

-- Spending per store
SELECT s.name, SUM(t.total) as total
FROM transactions t
JOIN stores s ON t.store_id = s.id
GROUP BY s.id ORDER BY total DESC;
```

## Ruby Console

```bash
just console
```

```ruby
# API client
client = PingoDoce::Client.new
client.login
client.latest_transaction_with_details
client.search_products("mleko", store_id: 17)
client.lookup_barcode("5601041001163", store_id: 17)

# Database access
storage = PingoDoce::Storage.new
storage.stats
storage.all_products.first(5)
storage.search_products("chleb")
```

## Reset Database

```bash
rm data/pingodoce.db
just db-setup
just sync --pages 10
```

## Project Structure

```
lib/
  pingo_doce.rb              # Main module
  pingo_doce/
    client.rb                # API client
    storage.rb               # Database operations
    analytics.rb             # Analytics service
    product_enricher.rb      # Product enrichment
    nutrition_parser.rb      # Nutrition HTML parser
    cli.rb                   # Thor CLI
data/
  pingodoce.db               # SQLite database (gitignored)
docs/
  API.md                     # API documentation
```

## Configuration

Environment variables (set in `.env`):

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PHONE_NUMBER` | Yes | - | Your Pingo Doce phone number (+351...) |
| `PASSWORD` | Yes | - | Your Pingo Doce password |
| `DATA_DIR` | No | `./data` | Directory for database |
| `DEFAULT_STORE_ID` | No | `17` | Store ID for catalog lookups |
| `LOG_LEVEL` | No | `info` | Logging level (debug, info, warn, error) |

## Security

- Never commit your `.env` file
- Database is stored in `data/` (gitignored)
- Credentials are loaded from environment variables only

## License

MIT
