#!/usr/bin/env ruby

# Analytics module for Pingo Doce transaction data
# Provides spending analysis, product tracking, and reporting

require 'json'
require 'date'
require 'fileutils'

class PingoDoceAnalytics
  def initialize(data_dir = 'data')
    @data_dir = data_dir
    @transactions_file = File.join(@data_dir, 'transactions.json')
    @products_file = File.join(@data_dir, 'products.json')

    FileUtils.mkdir_p(@data_dir)

    @transactions = load_transactions
    @products = load_products
  end

  # Save a transaction to the database
  def save_transaction(transaction_data, transaction_details = nil)
    transaction_id = transaction_data['transactionId']

    # Merge basic transaction info with detailed info if available
    full_transaction = transaction_data.dup
    if transaction_details
      full_transaction['details'] = transaction_details
      full_transaction['products'] = transaction_details['products']
    end

    full_transaction['saved_at'] = Time.now.iso8601

    @transactions[transaction_id] = full_transaction

    # Save individual products for analysis
    if transaction_details && transaction_details['products']
      transaction_details['products'].each do |product|
        save_product(product, transaction_data)
      end
    end

    save_data
    puts "💾 Saved transaction #{transaction_id} to database"
  end

  # Save product information for tracking
  def save_product(product, transaction_data)
    product_id = product['productId'] || product['name']

    if @products[product_id]
      # Update existing product with new purchase
      @products[product_id]['purchases'] << {
        'transaction_id' => transaction_data['transactionId'],
        'date' => transaction_data['transactionDate'],
        'store' => transaction_data['storeName'],
        'quantity' => product['purchaseQuantity'],
        'price' => product['purchasePrice'],
        'total' => product['totalAmount']
      }
    else
      # New product
      @products[product_id] = {
        'name' => product['name'],
        'category' => product['category'],
        'brand' => product['brand'],
        'image' => product['image'],
        'first_seen' => transaction_data['transactionDate'],
        'purchases' => [{
          'transaction_id' => transaction_data['transactionId'],
          'date' => transaction_data['transactionDate'],
          'store' => transaction_data['storeName'],
          'quantity' => product['purchaseQuantity'],
          'price' => product['purchasePrice'],
          'total' => product['totalAmount']
        }]
      }
    end
  end

  # Generate spending report
  def generate_spending_report(days = 30)
    puts "\n📊 SPENDING REPORT (Last #{days} days)"
    puts "=" * 50

    cutoff_date = Date.today - days
    recent_transactions = @transactions.values.select do |t|
      Date.parse(t['transactionDate']) >= cutoff_date
    end

    if recent_transactions.empty?
      puts "No transactions found in the last #{days} days"
      return
    end

    # Total spending
    total_spent = recent_transactions.sum { |t| t['total'].to_f }
    puts "💰 Total Spent: €#{total_spent.round(2)}"
    puts "🛍️  Total Transactions: #{recent_transactions.length}"
    puts "📊 Average per Transaction: €#{(total_spent / recent_transactions.length).round(2)}"

    # Spending by store
    puts "\n🏪 SPENDING BY STORE:"
    store_spending = recent_transactions.group_by { |t| t['storeName'] }
                                      .transform_values { |transactions| transactions.sum { |t| t['total'].to_f } }
                                      .sort_by { |_, amount| -amount }

    store_spending.each do |store, amount|
      puts "   #{store}: €#{amount.round(2)}"
    end

    # Most purchased products
    puts "\n🔥 TOP PRODUCTS:"
    product_frequency = {}

    recent_transactions.each do |transaction|
      next unless transaction['products']

      transaction['products'].each do |product|
        name = product['name']
        quantity = product['purchaseQuantity'].to_i
        product_frequency[name] = (product_frequency[name] || 0) + quantity
      end
    end

    top_products = product_frequency.sort_by { |_, count| -count }.first(10)
    top_products.each_with_index do |(product, count), index|
      puts "   #{index + 1}. #{product} (#{count}x)"
    end

    # Spending by day of week
    puts "\n📅 SPENDING BY DAY OF WEEK:"
    day_spending = Hash.new(0)
    recent_transactions.each do |transaction|
      day = Date.parse(transaction['transactionDate']).strftime('%A')
      day_spending[day] += transaction['total'].to_f
    end

    day_spending.sort_by { |_, amount| -amount }.each do |day, amount|
      puts "   #{day}: €#{amount.round(2)}"
    end
  end

  # Find product price trends
  def analyze_product_prices(product_name = nil)
    puts "\n💱 PRODUCT PRICE ANALYSIS"
    puts "=" * 40

    products_to_analyze = if product_name
      @products.select { |_, product| product['name'].downcase.include?(product_name.downcase) }
    else
      # Show products with multiple purchases
      @products.select { |_, product| product['purchases'].length > 1 }
    end

    if products_to_analyze.empty?
      puts "No products found with multiple purchases for price analysis"
      return
    end

    products_to_analyze.each do |product_id, product|
      next if product['purchases'].length < 2

      purchases = product['purchases'].sort_by { |p| Date.parse(p['date']) }
      first_price = purchases.first['price'].to_f
      last_price = purchases.last['price'].to_f
      price_change = last_price - first_price

      puts "\n📦 #{product['name']}"
      puts "   First seen: #{purchases.first['date']} at €#{first_price}"
      puts "   Last seen: #{purchases.last['date']} at €#{last_price}"

      if price_change > 0
        puts "   📈 Price increased by €#{price_change.round(2)} (+#{((price_change/first_price)*100).round(1)}%)"
      elsif price_change < 0
        puts "   📉 Price decreased by €#{price_change.abs.round(2)} (-#{((price_change.abs/first_price)*100).round(1)}%)"
      else
        puts "   ➡️  Price unchanged"
      end

      puts "   🛒 Total purchases: #{purchases.length}"
    end
  end

  # Export data to CSV
  def export_to_csv
    require 'csv'

    puts "\n📤 Exporting data to CSV..."

    # Export transactions
    CSV.open(File.join(@data_dir, 'transactions.csv'), 'w') do |csv|
      csv << ['Transaction ID', 'Date', 'Store', 'Total', 'Items Count', 'Store ID']

      @transactions.each do |id, transaction|
        csv << [
          id,
          transaction['transactionDate'],
          transaction['storeName'],
          transaction['total'],
          transaction['totalItems'],
          transaction['storeId']
        ]
      end
    end

    # Export products
    CSV.open(File.join(@data_dir, 'products.csv'), 'w') do |csv|
      csv << ['Product Name', 'Category', 'Brand', 'Total Purchases', 'First Seen', 'Avg Price']

      @products.each do |id, product|
        avg_price = product['purchases'].sum { |p| p['price'].to_f } / product['purchases'].length

        csv << [
          product['name'],
          product['category'],
          product['brand'],
          product['purchases'].length,
          product['first_seen'],
          avg_price.round(2)
        ]
      end
    end

    puts "✅ Exported to #{@data_dir}/transactions.csv and #{@data_dir}/products.csv"
  end

  # Get transaction by ID
  def get_transaction(transaction_id)
    @transactions[transaction_id]
  end

  # Check if transaction already exists
  def transaction_exists?(transaction_id)
    @transactions.key?(transaction_id)
  end

  # Get statistics
  def get_stats
    {
      total_transactions: @transactions.length,
      total_products: @products.length,
      date_range: {
        earliest: @transactions.values.map { |t| t['transactionDate'] }.min,
        latest: @transactions.values.map { |t| t['transactionDate'] }.max
      },
      total_spent: @transactions.values.sum { |t| t['total'].to_f }.round(2)
    }
  end

  private

  def load_transactions
    return {} unless File.exist?(@transactions_file)
    JSON.parse(File.read(@transactions_file))
  rescue JSON::ParserError
    puts "⚠️  Warning: Could not parse transactions file, starting fresh"
    {}
  end

  def load_products
    return {} unless File.exist?(@products_file)
    JSON.parse(File.read(@products_file))
  rescue JSON::ParserError
    puts "⚠️  Warning: Could not parse products file, starting fresh"
    {}
  end

  def save_data
    File.write(@transactions_file, JSON.pretty_generate(@transactions))
    File.write(@products_file, JSON.pretty_generate(@products))
  end
end
