# frozen_string_literal: true

require "date"
require "fileutils"

module PingoDoce
  class Analytics
    def initialize(storage: nil, data_dir: nil, logger: nil)
      @data_dir = data_dir || PingoDoce.configuration.data_dir
      @logger = logger || PingoDoce.logger
      @storage = storage || Storage.new(logger: @logger)

      FileUtils.mkdir_p(@data_dir)
    end

    # Delegate storage operations to Storage

    def save_transaction(transaction_data, transaction_details = nil)
      @storage.save_transaction(transaction_data, transaction_details)
    end

    def transaction_exists?(transaction_id)
      @storage.transaction_exists?(transaction_id)
    end

    def get_transaction(transaction_id)
      @storage.get_transaction(transaction_id)
    end

    # Analytics and reporting

    def spending_report(days: 30)
      cutoff_date = Date.today - days
      recent = @storage.recent_transactions(cutoff_date)

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
        @storage.search_products(product_name)
      else
        @storage.products_with_multiple_purchases
      end

      products_to_analyze.filter_map do |product|
        analyze_product_prices(product)
      end
    end

    def export_csv
      @storage.export_csv(@data_dir)
    end

    def stats
      @storage.stats
    end

    private

    attr_reader :logger

    def log_info(message)
      logger.info(message)
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
        date_str = t["transactionDate"]
        next unless date_str

        day = Date.parse(date_str.to_s).strftime("%A")
        result[day] += t["total"].to_f
      end
      result.transform_values { |v| v.round(2) }.sort_by { |_, v| -v }.to_h
    end

    def top_products(transactions, limit:)
      frequency = Hash.new(0)
      transactions.each do |t|
        t["products"]&.each do |p|
          quantity = p["purchaseQuantity"].to_s.tr(",", ".").to_f
          quantity = 1 if quantity.zero?
          frequency[p["name"]] += quantity.to_i
        end
      end
      frequency.sort_by { |_, count| -count }.first(limit).to_h
    end

    def analyze_product_prices(product)
      purchases = product["purchases"]
      return nil if purchases.nil? || purchases.length < 2

      sorted = purchases.sort_by { |p| Date.parse(p["date"].to_s) }
      first_price = parse_price(sorted.first["price"])
      last_price = parse_price(sorted.last["price"])

      return nil if first_price.nil? || last_price.nil?

      change = last_price - first_price

      {
        product_id: product["id"],
        name: product["name"],
        first_seen: sorted.first["date"],
        first_price: first_price,
        last_seen: sorted.last["date"],
        last_price: last_price,
        price_change: change.round(2),
        percent_change: first_price.zero? ? 0 : ((change / first_price) * 100).round(1),
        total_purchases: purchases.length
      }
    end

    def parse_price(value)
      return nil if value.nil?
      return value.to_f if value.is_a?(Numeric)

      value.to_s.tr(",", ".").to_f
    end

    def empty_report(days)
      {period_days: days, message: "No transactions found in the last #{days} days"}
    end
  end
end
