# frozen_string_literal: true

require "json"
require "date"
require "fileutils"
require "csv"

module PingoDoce
  class Analytics
    def initialize(data_dir: nil, logger: nil)
      @data_dir = data_dir || PingoDoce.configuration.data_dir
      @logger = logger || PingoDoce.logger
      @transactions_file = File.join(@data_dir, "transactions.json")
      @products_file = File.join(@data_dir, "products.json")

      FileUtils.mkdir_p(@data_dir)
      @transactions = load_json(@transactions_file)
      @products = load_json(@products_file)
    end

    def save_transaction(transaction_data, transaction_details = nil)
      transaction_id = transaction_data["transactionId"]

      full_transaction = transaction_data.dup
      if transaction_details
        full_transaction["details"] = transaction_details
        full_transaction["products"] = transaction_details["products"]

        transaction_details["products"]&.each do |product|
          save_product(product, transaction_data)
        end
      end

      full_transaction["saved_at"] = Time.now.iso8601
      @transactions[transaction_id] = full_transaction

      save_data
      log_info "Saved transaction #{transaction_id}"
    end

    def spending_report(days: 30)
      cutoff_date = Date.today - days
      recent = recent_transactions(cutoff_date)

      return empty_report(days) if recent.empty?

      {
        period_days: days,
        total_spent: recent.sum { |t| t["total"].to_f }.round(2),
        transaction_count: recent.length,
        average_per_transaction: (recent.sum { |t| t["total"].to_f } / recent.length).round(2),
        by_store: spending_by_store(recent),
        by_day_of_week: spending_by_day(recent),
        top_products: top_products(recent, limit: 10)
      }
    end

    def price_trends(product_name: nil)
      products_to_analyze = if product_name
        @products.select { |_, p| p["name"].downcase.include?(product_name.downcase) }
      else
        @products.select { |_, p| p["purchases"].length > 1 }
      end

      products_to_analyze.filter_map do |id, product|
        analyze_product_prices(id, product)
      end
    end

    def export_csv
      export_transactions_csv
      export_products_csv
      log_info "Exported to #{@data_dir}/transactions.csv and products.csv"
    end

    def stats
      return empty_stats if @transactions.empty?

      {
        total_transactions: @transactions.length,
        total_products: @products.length,
        date_range: date_range,
        total_spent: @transactions.values.sum { |t| t["total"].to_f }.round(2)
      }
    end

    def transaction_exists?(transaction_id)
      @transactions.key?(transaction_id)
    end

    def get_transaction(transaction_id)
      @transactions[transaction_id]
    end

    private

    attr_reader :logger

    def log_info(message)
      logger.info(message)
    end

    def load_json(file)
      return {} unless File.exist?(file)
      JSON.parse(File.read(file))
    rescue JSON::ParserError
      log_info "Warning: Could not parse #{file}, starting fresh"
      {}
    end

    def save_data
      File.write(@transactions_file, JSON.pretty_generate(@transactions))
      File.write(@products_file, JSON.pretty_generate(@products))
    end

    def save_product(product, transaction_data)
      product_id = product["productId"] || product["name"]
      purchase_record = build_purchase_record(product, transaction_data)

      if @products[product_id]
        @products[product_id]["purchases"] << purchase_record
      else
        @products[product_id] = build_new_product(product, transaction_data, purchase_record)
      end
    end

    def build_purchase_record(product, transaction_data)
      {
        "transaction_id" => transaction_data["transactionId"],
        "date" => transaction_data["transactionDate"],
        "store" => transaction_data["storeName"],
        "quantity" => product["purchaseQuantity"],
        "price" => product["purchasePrice"],
        "total" => product["totalAmount"]
      }
    end

    def build_new_product(product, transaction_data, purchase_record)
      {
        "name" => product["name"],
        "category" => product["category"],
        "brand" => product["brand"],
        "image" => product["image"],
        "first_seen" => transaction_data["transactionDate"],
        "purchases" => [purchase_record]
      }
    end

    def recent_transactions(cutoff_date)
      @transactions.values.select do |t|
        Date.parse(t["transactionDate"]) >= cutoff_date
      end
    end

    def spending_by_store(transactions)
      transactions
        .group_by { |t| t["storeName"] }
        .transform_values { |txns| txns.sum { |t| t["total"].to_f }.round(2) }
        .sort_by { |_, amount| -amount }
        .to_h
    end

    def spending_by_day(transactions)
      result = Hash.new(0)
      transactions.each do |t|
        day = Date.parse(t["transactionDate"]).strftime("%A")
        result[day] += t["total"].to_f
      end
      result.transform_values { |v| v.round(2) }.sort_by { |_, v| -v }.to_h
    end

    def top_products(transactions, limit:)
      frequency = Hash.new(0)
      transactions.each do |t|
        t["products"]&.each do |p|
          frequency[p["name"]] += p["purchaseQuantity"].to_i
        end
      end
      frequency.sort_by { |_, count| -count }.first(limit).to_h
    end

    def analyze_product_prices(id, product)
      return nil if product["purchases"].length < 2

      purchases = product["purchases"].sort_by { |p| Date.parse(p["date"]) }
      first_price = purchases.first["price"].to_f
      last_price = purchases.last["price"].to_f
      change = last_price - first_price

      {
        product_id: id,
        name: product["name"],
        first_seen: purchases.first["date"],
        first_price: first_price,
        last_seen: purchases.last["date"],
        last_price: last_price,
        price_change: change.round(2),
        percent_change: first_price.zero? ? 0 : ((change / first_price) * 100).round(1),
        total_purchases: purchases.length
      }
    end

    def date_range
      dates = @transactions.values.map { |t| t["transactionDate"] }
      {earliest: dates.min, latest: dates.max}
    end

    def empty_report(days)
      {period_days: days, message: "No transactions found in the last #{days} days"}
    end

    def empty_stats
      {
        total_transactions: 0,
        total_products: 0,
        date_range: {earliest: nil, latest: nil},
        total_spent: 0
      }
    end

    def export_transactions_csv
      CSV.open(File.join(@data_dir, "transactions.csv"), "w") do |csv|
        csv << ["Transaction ID", "Date", "Store", "Total", "Items Count", "Store ID"]
        @transactions.each do |id, t|
          csv << [id, t["transactionDate"], t["storeName"], t["total"], t["totalItems"], t["storeId"]]
        end
      end
    end

    def export_products_csv
      CSV.open(File.join(@data_dir, "products.csv"), "w") do |csv|
        csv << ["Product Name", "Category", "Brand", "Total Purchases", "First Seen", "Avg Price"]
        @products.each do |_, p|
          avg = p["purchases"].empty? ? 0 : p["purchases"].sum { |pr| pr["price"].to_f } / p["purchases"].length
          csv << [p["name"], p["category"], p["brand"], p["purchases"].length, p["first_seen"], avg.round(2)]
        end
      end
    end
  end
end
