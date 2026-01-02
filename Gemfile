# frozen_string_literal: true

source "https://rubygems.org"

# Core
gem "zeitwerk"    # autoloading
gem "thor"        # CLI
gem "httparty"    # HTTP client
gem "dotenv"      # env vars

# Database
gem "sequel"      # ORM
gem "sqlite3"     # SQLite adapter

# Development
group :development do
  gem "standard"  # linting (rubocop wrapper)
  gem "lefthook"  # git hooks
  gem "bundle-audit"
end

# Test
group :test do
  gem "rspec"
  gem "webmock"
end
