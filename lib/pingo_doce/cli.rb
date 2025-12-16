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
    option :enrich, type: :boolean, default: true, desc: "Enrich products with catalog data"
    option :store, type: :numeric, desc: "Store ID for enrichment (default from config)"
    def sync
      client = Client.new
      client.login

      analytics_service = Analytics.new
      total_synced = 0
      total_skipped = 0
      last_store_id = options[:store] || PingoDoce.configuration.default_store_id

      (1..options[:pages]).each do |page|
        say "Fetching page #{page}...", :cyan
        txns = client.transactions(page: page, size: options[:size])

        break if txns.empty?

        txns.each do |transaction|
          transaction_id = transaction["transactionId"]
          last_store_id = transaction["storeId"] || last_store_id

          if analytics_service.transaction_exists?(transaction_id)
            total_skipped += 1
            next
          end

          begin
            details = client.transaction_details(transaction_id, store_id: transaction["storeId"])
            analytics_service.save_transaction(transaction, details)
            total_synced += 1
            say "  Synced: #{transaction["transactionDate"]} - #{transaction["storeName"]} - #{transaction["total"]} EUR", :green
          rescue => e
            say "  Failed to sync #{transaction_id}: #{e.message}", :red
          end
        end
      end

      say "\nSync complete! Synced: #{total_synced}, Skipped (already exists): #{total_skipped}", :green

      # Enrich new products
      if options[:enrich] && total_synced > 0
        enrich_pending_products(client, last_store_id)
      end
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

    desc "db_setup", "Create database tables"
    def db_setup
      say "Setting up database...", :cyan
      say "  Database: #{PingoDoce.configuration.database_url}", :cyan

      Database.setup!
      say "Database tables created successfully!", :green
    rescue DatabaseError => e
      say "Database Error: #{e.message}", :red
      exit 1
    end

    desc "db_status", "Show database status"
    def db_status
      config = PingoDoce.configuration

      say "Database Status:", :cyan
      say "  Database URL: #{mask_password(config.database_url)}"

      begin
        db = Database.connection
        say "  Connection: OK", :green

        if db.table_exists?(:transactions)
          txn_count = db[:transactions].count
          product_count = db[:products].count
          say "  Transactions: #{txn_count}"
          say "  Products: #{product_count}"
        else
          say "  Tables: Not created (run 'db_setup' first)", :yellow
        end
      rescue => e
        say "  Connection: FAILED - #{e.message}", :red
      end
    end

    desc "config", "Show current configuration"
    def config
      cfg = PingoDoce.configuration

      say "Current Configuration:", :cyan
      say "  Database: #{mask_password(cfg.database_url)}"
      say "  Data directory: #{cfg.data_dir}"
      say "  Phone number: #{cfg.phone_number ? mask_phone(cfg.phone_number) : "Not set"}"
      say "  Default store ID: #{cfg.default_store_id}"
      say "  Timeout: #{cfg.timeout}s"
      say "  Log level: #{ENV.fetch("LOG_LEVEL", "info")}"
    end

    desc "barcode", "Lookup product by barcode (EAN)"
    option :store, type: :numeric, desc: "Store ID for catalog lookup (default from config)"
    option :json, type: :boolean, default: false, desc: "Output as JSON"
    def barcode(ean)
      client = Client.new
      client.login

      store_id = options[:store] || PingoDoce.configuration.default_store_id
      result = client.lookup_barcode(ean, store_id: store_id)

      if result
        if options[:json]
          say JSON.pretty_generate(result)
        else
          display_catalog_product(result)
        end
      else
        say "Product not found for EAN: #{ean}", :yellow
      end
    rescue AuthenticationError, APIError => e
      say "Error: #{e.message}", :red
      exit 1
    end

    desc "health", "Generate health analysis report"
    option :days, type: :numeric, desc: "Analyze last N days only"
    option :json, type: :boolean, default: false, desc: "Output as JSON"
    def health
      require_relative "health_analyzer"

      analyzer = HealthAnalyzer.new(days: options[:days])
      report = analyzer.generate

      if options[:json]
        say JSON.pretty_generate(report)
      else
        display_health_report(report)
      end
    end

    desc "enrich_all", "Enrich all products with catalog data (batch)"
    option :limit, type: :numeric, default: 100, desc: "Max products to process"
    option :store, type: :numeric, desc: "Store ID (default from config)"
    option :delay, type: :numeric, default: 0.5, desc: "Delay between API calls (seconds)"
    def enrich_all
      client = Client.new
      client.login

      storage = Storage.new
      store_id = options[:store] || PingoDoce.configuration.default_store_id

      products = storage.products_needing_enrichment(limit: options[:limit])

      if products.empty?
        say "No products need enrichment", :yellow
        return
      end

      say "Found #{products.length} products to enrich...", :cyan

      enricher = ProductEnricher.new(
        client: client,
        storage: storage,
        store_id: store_id
      )

      results = enricher.enrich_batch(products, delay: options[:delay])

      say "\nEnrichment complete!", :green
      say "  Enriched: #{results[:enriched]}"
      say "  Not found: #{results[:not_found]}"
      say "  Errors: #{results[:errors]}"
    rescue AuthenticationError, APIError => e
      say "Error: #{e.message}", :red
      exit 1
    end

    desc "db_import", "Import data from JSON files"
    option :from, type: :string, default: "data", desc: "Directory with JSON files"
    def db_import
      json_dir = options[:from]

      unless File.exist?(File.join(json_dir, "transactions.json"))
        say "No transactions.json found in #{json_dir}", :red
        exit 1
      end

      say "Importing data from #{json_dir}...", :cyan

      importer = JsonImporter.new(logger: PingoDoce.logger)
      result = importer.import(json_dir: json_dir)

      say "Import complete!", :green
      say "  Transactions imported: #{result[:transactions]}"
      say "  Products imported: #{result[:products]}"
      say "  Skipped (already exists): #{result[:skipped]}"
    rescue => e
      say "Import Error: #{e.message}", :red
      exit 1
    end

    private

    def mask_password(url)
      return url unless url

      url.gsub(/:[^@:]+@/, ":****@")
    end

    def mask_phone(phone)
      return phone unless phone && phone.length > 6

      "#{phone[0..5]}****#{phone[-2..]}"
    end

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

    def display_catalog_product(product)
      say "\nProduct:", :cyan
      say "  Name: #{product["name"]}"
      say "  EAN: #{product["ean"]}" if product["ean"]
      say "  Price: #{product["storePrice"]} EUR" if product["storePrice"]
      say "  Brand: #{product.dig("brand", "name")}" if product.dig("brand", "name")
      say "  Category: #{product["category"]}" if product["category"]

      if product["description"]
        nutrition = NutritionParser.parse(product["description"])

        if nutrition[:energy_kcal]
          say "\n  Nutrition (per 100g):", :cyan
          say "    Energy: #{nutrition[:energy_kcal]} kcal"
          say "    Fat: #{nutrition[:fat]}g" if nutrition[:fat]
          say "    Saturated fat: #{nutrition[:saturated_fat]}g" if nutrition[:saturated_fat]
          say "    Carbohydrates: #{nutrition[:carbohydrates]}g" if nutrition[:carbohydrates]
          say "    Sugars: #{nutrition[:sugars]}g" if nutrition[:sugars]
          say "    Fiber: #{nutrition[:fiber]}g" if nutrition[:fiber]
          say "    Protein: #{nutrition[:protein]}g" if nutrition[:protein]
          say "    Salt: #{nutrition[:salt]}g" if nutrition[:salt]
        end

        if nutrition[:ingredients]
          say "\n  Ingredients:", :cyan
          say "    #{nutrition[:ingredients][0, 200]}#{"..." if nutrition[:ingredients].length > 200}"
        end
      end
    end

    def enrich_pending_products(client, store_id, limit: 20)
      storage = Storage.new
      products = storage.products_needing_enrichment(limit: limit)

      if products.empty?
        say "\nNo products need enrichment", :cyan
        return
      end

      say "\nEnriching #{products.length} products...", :cyan

      enricher = ProductEnricher.new(
        client: client,
        storage: storage,
        store_id: store_id
      )

      results = enricher.enrich_batch(products, delay: 0.3)

      say "Enrichment: #{results[:enriched]} enriched, #{results[:not_found]} not found", :green
    end

    def display_health_report(report)
      say "\n=== Health Report ===", :cyan
      say "Generated: #{report[:generated_at]}"
      say "Period: #{report[:period][:days_analyzed]} days"
      say "Transactions: #{report[:summary][:transactions]}"
      say "Total spent: #{report[:summary][:total_spent_eur]} EUR"

      say "\n--- Health Scores ---", :cyan
      scores = report[:health_scores]
      scores.each do |key, value|
        color = if value >= 70
          :green
        else
          ((value >= 40) ? :yellow : :red)
        end
        say "  #{format_score_name(key)}: #{value}%", color
      end

      say "\n--- Top Categories ---", :cyan
      %i[protein fermented legumes nuts_seeds greens vegetables fruits healthy_fats].each do |cat|
        data = report[:categories][cat]
        next if data.nil? || data[:total_purchases] == 0

        say "\n#{data[:name]} (#{data[:total_purchases]} purchases):"
        data[:products].first(5).each do |p|
          say "  - #{p[:name]} (#{p[:count]}x)"
        end
      end

      if report[:recommendations].any?
        say "\n--- Recommendations ---", :yellow
        report[:recommendations].each do |rec|
          say "\n[Priority #{rec[:priority]}] #{rec[:category].upcase}"
          say "  Issue: #{rec[:issue]}"
          say "  Action: #{rec[:action]}"
        end
      end

      say "\n--- Fresh Produce ---", :cyan
      say "Vegetable variety: #{report[:fresh_produce][:vegetable_variety]} types"
      say "Fruit variety: #{report[:fresh_produce][:fruit_variety]} types"
    end

    def format_score_name(key)
      key.to_s.tr("_", " ").gsub("score", "").strip.capitalize
    end
  end
end
