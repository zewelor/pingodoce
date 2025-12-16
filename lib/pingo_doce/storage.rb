# frozen_string_literal: true

require "json"
require "csv"

module PingoDoce
  class Storage
    def initialize(db: nil, logger: nil)
      @db = db || Database.connection
      @logger = logger || PingoDoce.logger
    end

    # Transaction operations

    def save_transaction(transaction_data, transaction_details = nil)
      @db.transaction do
        store = find_or_create_store(transaction_data)
        txn_record = save_transaction_record(transaction_data, transaction_details, store)

        if transaction_details&.dig("products")
          transaction_details["products"].each do |product|
            save_product_purchase(product, transaction_data, txn_record, store)
          end
        end

        log_info "Saved transaction #{transaction_data["transactionId"]}"
        txn_record
      end
    rescue Sequel::DatabaseError => e
      raise StorageError, "Failed to save transaction: #{e.message}"
    end

    def transaction_exists?(transaction_id)
      @db[:transactions].where(transaction_id: transaction_id).count > 0
    end

    def get_transaction(transaction_id)
      txn = @db[:transactions].where(transaction_id: transaction_id).first
      return nil unless txn

      store = @db[:stores].where(id: txn[:store_id]).first
      purchases = @db[:purchases]
        .join(:products, id: :product_id)
        .where(transaction_id: txn[:id])
        .select_all(:purchases)
        .select_append(Sequel[:products][:name].as(:product_name))
        .all

      build_transaction_hash(txn, store, purchases)
    end

    def all_transactions
      @db[:transactions]
        .left_join(:stores, id: :store_id)
        .select_all(:transactions)
        .select_append(Sequel[:stores][:name].as(:store_name))
        .order(Sequel.desc(:transaction_date))
        .all
    end

    def recent_transactions(cutoff_date)
      @db[:transactions]
        .left_join(:stores, id: :store_id)
        .where { transaction_date >= cutoff_date }
        .select_all(:transactions)
        .select_append(Sequel[:stores][:name].as(:store_name))
        .order(Sequel.desc(:transaction_date))
        .map { |txn| build_transaction_with_products(txn) }
    end

    # Product operations

    def all_products
      @db[:products]
        .left_join(:brands, id: :brand_id)
        .select_all(:products)
        .select_append(Sequel[:brands][:name].as(:brand_name))
        .all
    end

    def products_with_multiple_purchases
      product_ids = @db[:purchases]
        .group(:product_id)
        .having { count(id) > 1 }
        .select(:product_id)

      @db[:products]
        .where(id: product_ids)
        .all
        .map { |p| build_product_with_purchases(p) }
    end

    def search_products(pattern)
      search_pattern = "%#{pattern}%"
      @db[:products]
        .where(Sequel.ilike(:name, search_pattern))
        .all
        .map { |p| build_product_with_purchases(p) }
    end

    def find_product_by_ean(ean)
      @db[:products].where(ean: ean).first
    end

    def find_product_by_external_id(external_id)
      @db[:products].where(external_id: external_id.to_s).first
    end

    def products_needing_enrichment(limit: 50)
      @db[:products]
        .where(Sequel.|({enrichment_status: nil}, {enrichment_status: "pending"}))
        .limit(limit)
        .all
    end

    def enrich_product(product_id, catalog_data)
      @db.transaction do
        update_data = {
          ean: catalog_data["ean"],
          description_html: catalog_data["description"],
          store_price: parse_decimal(catalog_data["storePrice"]),
          enrichment_status: "enriched",
          last_enriched_at: Time.now
        }

        # Extract and save ingredients
        if catalog_data["description"]
          nutrition = NutritionParser.parse(catalog_data["description"])
          update_data[:ingredients] = nutrition[:ingredients]
          save_product_nutrition(product_id, nutrition)
        end

        # Update image if we have a better one
        if catalog_data["image"] && !catalog_data["image"].empty?
          update_data[:image] = catalog_data["image"]
        end

        @db[:products].where(id: product_id).update(update_data)
        log_info "Enriched product #{product_id}"
      end
    rescue Sequel::DatabaseError => e
      raise StorageError, "Failed to enrich product: #{e.message}"
    end

    def save_product_nutrition(product_id, nutrition_data)
      return unless nutrition_data[:energy_kcal] || nutrition_data[:protein]

      existing = @db[:product_nutritions].where(product_id: product_id).first

      data = {
        energy_kj: nutrition_data[:energy_kj],
        energy_kcal: nutrition_data[:energy_kcal],
        fat: nutrition_data[:fat],
        saturated_fat: nutrition_data[:saturated_fat],
        carbohydrates: nutrition_data[:carbohydrates],
        sugars: nutrition_data[:sugars],
        fiber: nutrition_data[:fiber],
        protein: nutrition_data[:protein],
        salt: nutrition_data[:salt]
      }

      if existing
        @db[:product_nutritions].where(id: existing[:id]).update(data)
      else
        @db[:product_nutritions].insert(data.merge(product_id: product_id, created_at: Time.now))
      end
    end

    def get_product_nutrition(product_id)
      @db[:product_nutritions].where(product_id: product_id).first
    end

    def mark_product_unavailable(product_id)
      @db[:products].where(id: product_id).update(
        enrichment_status: "unavailable",
        last_enriched_at: Time.now
      )
    end

    # Statistics

    def stats
      txn_count = @db[:transactions].count
      return empty_stats if txn_count.zero?

      total_spent = @db[:transactions].sum(:total) || 0
      dates = @db[:transactions].select(:transaction_date).order(:transaction_date)
      earliest = dates.first&.dig(:transaction_date)
      latest = dates.last&.dig(:transaction_date)

      {
        total_transactions: txn_count,
        total_products: @db[:products].count,
        date_range: {earliest: earliest&.to_s, latest: latest&.to_s},
        total_spent: total_spent.to_f.round(2)
      }
    end

    # Export

    def export_csv(output_dir)
      export_transactions_csv(output_dir)
      export_products_csv(output_dir)
      log_info "Exported to #{output_dir}/transactions.csv and products.csv"
    end

    private

    attr_reader :logger

    def log_info(message)
      logger.info(message)
    end

    def find_or_create_store(transaction_data)
      external_id = transaction_data["storeId"].to_s
      name = transaction_data["storeName"] || "Unknown Store"

      store = @db[:stores].where(external_id: external_id).first
      return store if store

      id = @db[:stores].insert(
        external_id: external_id,
        name: name,
        created_at: Time.now
      )
      @db[:stores].where(id: id).first
    end

    def save_transaction_record(transaction_data, transaction_details, store)
      transaction_id = transaction_data["transactionId"]

      existing = @db[:transactions].where(transaction_id: transaction_id).first
      if existing
        @db[:transactions].where(id: existing[:id]).update(
          details: transaction_details&.to_json,
          saved_at: Time.now
        )
        return existing
      end

      id = @db[:transactions].insert(
        transaction_id: transaction_id,
        store_id: store[:id],
        total_items: transaction_data["totalItems"],
        total_discount: parse_decimal(transaction_data["totalDiscount"]),
        total: parse_decimal(transaction_data["total"]),
        transaction_date: parse_datetime(transaction_data["transactionDate"]),
        details: transaction_details&.to_json,
        saved_at: Time.now
      )
      @db[:transactions].where(id: id).first
    end

    def save_product_purchase(product, transaction_data, txn_record, store)
      brand = find_or_create_brand(product["brand"]) if product["brand"]

      db_product = find_or_create_product(product, transaction_data, brand)

      # Check if purchase already exists
      existing = @db[:purchases].where(
        product_id: db_product[:id],
        transaction_id: txn_record[:id]
      ).first
      return if existing

      @db[:purchases].insert(
        product_id: db_product[:id],
        transaction_id: txn_record[:id],
        store_id: store[:id],
        quantity: parse_decimal(product["purchaseQuantity"]),
        price: parse_price(product["purchasePrice"]),
        total: parse_decimal(product["totalAmount"]),
        purchase_date: parse_datetime(transaction_data["transactionDate"])
      )
    end

    def find_or_create_brand(brand_data)
      return nil unless brand_data

      external_id = brand_data["id"]
      name = brand_data["name"] || "Unknown"

      existing = @db[:brands].where(external_id: external_id).first
      return existing if existing

      id = @db[:brands].insert(
        external_id: external_id,
        name: name,
        own_brand: brand_data["ownBrand"] || false,
        logo: brand_data["logo"],
        created_at: Time.now
      )
      @db[:brands].where(id: id).first
    end

    def find_or_create_product(product, transaction_data, brand)
      external_id = product["productId"] || product["elasticId"]
      name = product["name"]

      # Try to find by external_id first
      if external_id
        existing = @db[:products].where(external_id: external_id.to_s).first
        return existing if existing
      end

      # Try to find by name and brand
      query = @db[:products].where(name: name)
      query = query.where(brand_id: brand[:id]) if brand
      existing = query.first
      return existing if existing

      id = @db[:products].insert(
        external_id: external_id&.to_s,
        name: name,
        category: product["category"],
        category_id: product["categoryId"],
        brand_id: brand&.dig(:id),
        image: product["image"],
        first_seen: parse_datetime(transaction_data["transactionDate"]),
        created_at: Time.now
      )
      @db[:products].where(id: id).first
    end

    def build_transaction_hash(txn, store, purchases)
      details = txn[:details] ? JSON.parse(txn[:details]) : nil
      {
        "transactionId" => txn[:transaction_id],
        "storeId" => store&.dig(:external_id),
        "storeName" => store&.dig(:name),
        "totalItems" => txn[:total_items],
        "totalDiscount" => txn[:total_discount]&.to_f,
        "total" => txn[:total]&.to_f,
        "transactionDate" => txn[:transaction_date]&.iso8601,
        "details" => details,
        "products" => purchases.map do |p|
          {
            "name" => p[:product_name],
            "purchaseQuantity" => p[:quantity]&.to_f,
            "purchasePrice" => p[:price]&.to_f,
            "totalAmount" => p[:total]&.to_f
          }
        end,
        "saved_at" => txn[:saved_at]&.iso8601
      }
    end

    def build_transaction_with_products(txn)
      purchases = @db[:purchases]
        .join(:products, id: :product_id)
        .where(transaction_id: txn[:id])
        .select_all(:purchases)
        .select_append(Sequel[:products][:name].as(:product_name))
        .all

      {
        "transactionId" => txn[:transaction_id],
        "storeId" => txn[:store_id],
        "storeName" => txn[:store_name],
        "totalItems" => txn[:total_items],
        "totalDiscount" => txn[:total_discount]&.to_f,
        "total" => txn[:total]&.to_f,
        "transactionDate" => txn[:transaction_date]&.iso8601,
        "products" => purchases.map do |p|
          {
            "name" => p[:product_name],
            "purchaseQuantity" => p[:quantity]&.to_s,
            "purchasePrice" => p[:price]&.to_s,
            "totalAmount" => p[:total]&.to_f
          }
        end
      }
    end

    def build_product_with_purchases(product)
      purchases = @db[:purchases]
        .join(:transactions, id: :transaction_id)
        .left_join(:stores, Sequel[:stores][:id] => Sequel[:purchases][:store_id])
        .where(product_id: product[:id])
        .select(
          Sequel[:purchases][:quantity],
          Sequel[:purchases][:price],
          Sequel[:purchases][:total],
          Sequel[:purchases][:purchase_date],
          Sequel[:transactions][:transaction_id],
          Sequel[:stores][:name].as(:store_name)
        )
        .order(:purchase_date)
        .all

      {
        "id" => product[:id],
        "name" => product[:name],
        "category" => product[:category],
        "image" => product[:image],
        "first_seen" => product[:first_seen]&.iso8601,
        "purchases" => purchases.map do |p|
          {
            "transaction_id" => p[:transaction_id],
            "date" => p[:purchase_date]&.iso8601,
            "store" => p[:store_name],
            "quantity" => p[:quantity]&.to_s,
            "price" => p[:price]&.to_s,
            "total" => p[:total]&.to_f
          }
        end
      }
    end

    def parse_decimal(value)
      return nil if value.nil?
      return value if value.is_a?(Numeric)

      # Handle European format (comma as decimal separator)
      value.to_s.tr(",", ".").to_f
    end

    def parse_price(value)
      parse_decimal(value)
    end

    def parse_datetime(value)
      return nil if value.nil?
      return value if value.is_a?(Time) || value.is_a?(DateTime)

      DateTime.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def empty_stats
      {
        total_transactions: 0,
        total_products: 0,
        date_range: {earliest: nil, latest: nil},
        total_spent: 0
      }
    end

    def export_transactions_csv(output_dir)
      CSV.open(File.join(output_dir, "transactions.csv"), "w") do |csv|
        csv << ["Transaction ID", "Date", "Store", "Total", "Items Count"]

        @db[:transactions]
          .left_join(:stores, id: :store_id)
          .select_all(:transactions)
          .select_append(Sequel[:stores][:name].as(:store_name))
          .order(:transaction_date)
          .each do |txn|
            csv << [
              txn[:transaction_id],
              txn[:transaction_date],
              txn[:store_name],
              txn[:total],
              txn[:total_items]
            ]
          end
      end
    end

    def export_products_csv(output_dir)
      CSV.open(File.join(output_dir, "products.csv"), "w") do |csv|
        csv << ["Product Name", "Category", "Total Purchases", "First Seen", "Avg Price"]

        # Single query with aggregation instead of N+1
        @db[:products]
          .left_join(:purchases, product_id: :id)
          .select(
            Sequel[:products][:name],
            Sequel[:products][:category],
            Sequel[:products][:first_seen],
            Sequel.function(:count, Sequel[:purchases][:id]).as(:purchase_count),
            Sequel.function(:avg, Sequel[:purchases][:price]).as(:avg_price)
          )
          .group(Sequel[:products][:id])
          .each do |row|
            csv << [
              row[:name],
              row[:category],
              row[:purchase_count],
              row[:first_seen],
              row[:avg_price]&.round(2) || 0
            ]
          end
      end
    end
  end
end
