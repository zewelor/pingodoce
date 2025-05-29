# Pingo Doce API Client

A Ruby client for interacting with the Pingo Doce mobile app API to fetch transaction history and other account data.

## Setup

1. Install dependencies:
   ```bash
   bundle install
   ```

2. Create a `.env` file with your credentials:
   ```bash
   cp .env.example .env
   ```

3. Edit the `.env` file and add your Pingo Doce credentials:
   ```
   PHONE_NUMBER=+351123456789
   PASSWORD=your_password_here
   ```

## Usage

### Simple Fetch Script

Run the simple transaction fetcher:

```bash
ruby simple_fetch.rb
```

This script will:
- Login to your Pingo Doce account
- Fetch your transaction history
- Display the results in JSON format

## Files

- `simple_fetch.rb` - Simple script for login and transaction fetching
- `pingodoce_client.rb` - Full-featured client (if available)
- `.env` - Your credentials (not tracked in git)
- `.env.example` - Example environment file

## Security

- Never commit your `.env` file to version control
- The `.env` file is already included in `.gitignore`
- Keep your credentials secure
