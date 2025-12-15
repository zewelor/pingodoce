# frozen_string_literal: true

require "thor"
require "json"

module PingoDoce
  class Cli < Thor
    def self.exit_on_failure?
      true
    end

    desc "fetch", "Fetch latest transaction with details (default command)"
    option :save, type: :boolean, default: true, desc: "Save to analytics database"
    option :json, type: :boolean, default: false, desc: "Output as JSON"
    def fetch
      client = Client.new
      result = client.latest_transaction_with_details

      if result
        if options[:json]
          say JSON.pretty_generate(result)
        else
          display_transaction(result[:summary])
          display_details(result[:details])
        end

        if options[:save]
          analytics = Analytics.new
          analytics.save_transaction(result[:summary], result[:details])
          say "\nTransaction saved to database", :green unless options[:json]
        end
      else
        say "No transactions found", :yellow
      end
    rescue AuthenticationError => e
      say "Authentication Error: #{e.message}", :red
      exit 1
    rescue APIError => e
      say "API Error: #{e.message}", :red
      exit 1
    end

    default_task :fetch

    desc "transactions", "List transactions"
    option :page, type: :numeric, default: 1, desc: "Page number"
    option :size, type: :numeric, default: 10, desc: "Page size"
    option :json, type: :boolean, default: false, desc: "Output as JSON"
    def transactions
      client = Client.new
      client.login

      txns = client.transactions(page: options[:page], size: options[:size])

      if options[:json]
        say JSON.pretty_generate(txns)
      else
        display_transactions_list(txns)
      end
    rescue AuthenticationError, APIError => e
      say "Error: #{e.message}", :red
      exit 1
    end

    desc "sync", "Sync all transactions from API to local database"
    option :pages, type: :numeric, default: 5, desc: "Number of pages to fetch"
    option :size, type: :numeric, default: 20, desc: "Page size"
    def sync
      client = Client.new
      client.login

      analytics_service = Analytics.new
      total_synced = 0
      total_skipped = 0

      (1..options[:pages]).each do |page|
        say "Fetching page #{page}...", :cyan
        txns = client.transactions(page: page, size: options[:size])

        break if txns.empty?

        txns.each do |transaction|
          transaction_id = transaction["transactionId"]

          if analytics_service.transaction_exists?(transaction_id)
            total_skipped += 1
            next
          end

          begin
            details = client.transaction_details(transaction_id, store_id: transaction["storeId"])
            analytics_service.save_transaction(transaction, details)
            total_synced += 1
            say "  Synced: #{transaction["transactionDate"]} - #{transaction["storeName"]} - #{transaction["total"]} EUR", :green
          rescue StandardError => e
            say "  Failed to sync #{transaction_id}: #{e.message}", :red
          end
        end
      end

      say "\nSync complete! Synced: #{total_synced}, Skipped (already exists): #{total_skipped}", :green
    rescue AuthenticationError, APIError => e
      say "Error: #{e.message}", :red
      exit 1
    end

    desc "analytics", "Show spending analytics"
    option :days, type: :numeric, default: 30, desc: "Number of days to analyze"
    def analytics
      analytics_service = Analytics.new
      report = analytics_service.spending_report(days: options[:days])

      display_spending_report(report)
    end

    desc "prices", "Show product price trends"
    option :product, type: :string, desc: "Filter by product name"
    def prices
      analytics_service = Analytics.new
      trends = analytics_service.price_trends(product_name: options[:product])

      if trends.empty?
        say "No products with multiple purchases found for price analysis", :yellow
      else
        display_price_trends(trends)
      end
    end

    desc "export", "Export data to CSV"
    def export
      analytics_service = Analytics.new
      analytics_service.export_csv
      say "Data exported successfully!", :green
    end

    desc "stats", "Show database statistics"
    def stats
      analytics_service = Analytics.new
      stats = analytics_service.stats

      say "Database Statistics:", :cyan
      say "  Total transactions: #{stats[:total_transactions]}"
      say "  Total products: #{stats[:total_products]}"
      say "  Total spent: #{stats[:total_spent]} EUR"

      if stats[:date_range][:earliest]
        say "  Date range: #{stats[:date_range][:earliest]} to #{stats[:date_range][:latest]}"
      else
        say "  Date range: No data"
      end
    end

    desc "version", "Show version"
    def version
      say "PingoDoce CLI v#{VERSION}"
    end

    private

    def display_transaction(transaction)
      say "\nLatest Transaction:", :cyan
      say "  Date: #{transaction["transactionDate"]}"
      say "  Store: #{transaction["storeName"]}"
      say "  Total: #{transaction["total"]} EUR"
      say "  Items: #{transaction["totalItems"]}"
    end

    def display_details(details)
      return unless details

      say "\nProducts:", :cyan
      details["products"]&.each_with_index do |product, i|
        say "  #{i + 1}. #{product["purchaseQuantity"]}x #{product["name"]} - #{product["purchasePrice"]} EUR"
      end
    end

    def display_transactions_list(transactions)
      if transactions.empty?
        say "No transactions found", :yellow
        return
      end

      say "\nTransactions:", :cyan
      transactions.each_with_index do |t, i|
        say "  #{i + 1}. #{t["transactionDate"]} | #{t["storeName"]} | #{t["total"]} EUR | #{t["totalItems"]} items"
      end
    end

    def display_spending_report(report)
      if report[:message]
        say report[:message], :yellow
        return
      end

      say "\nSpending Report (Last #{report[:period_days]} days):", :cyan
      say "  Total Spent: #{report[:total_spent]} EUR"
      say "  Transactions: #{report[:transaction_count]}"
      say "  Average: #{report[:average_per_transaction]} EUR"

      say "\nBy Store:", :cyan
      report[:by_store].each { |store, amount| say "  #{store}: #{amount} EUR" }

      say "\nBy Day of Week:", :cyan
      report[:by_day_of_week].each { |day, amount| say "  #{day}: #{amount} EUR" }

      if report[:top_products].any?
        say "\nTop Products:", :cyan
        report[:top_products].each_with_index do |(product, count), i|
          say "  #{i + 1}. #{product} (#{count}x)"
        end
      end
    end

    def display_price_trends(trends)
      say "\nProduct Price Trends:", :cyan
      trends.each do |trend|
        direction = (trend[:price_change] >= 0) ? "+" : ""
        say "\n  #{trend[:name]}"
        say "    First: #{trend[:first_seen]} at #{trend[:first_price]} EUR"
        say "    Last: #{trend[:last_seen]} at #{trend[:last_price]} EUR"
        say "    Change: #{direction}#{trend[:price_change]} EUR (#{direction}#{trend[:percent_change]}%)"
        say "    Total purchases: #{trend[:total_purchases]}"
      end
    end
  end
end
