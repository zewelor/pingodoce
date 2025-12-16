# frozen_string_literal: true

module PingoDoce
  class DatabaseSetup
    class << self
      def run(db)
        create_stores_table(db)
        create_brands_table(db)
        create_transactions_table(db)
        create_products_table(db)
        create_purchases_table(db)
        create_product_nutritions_table(db)
        migrate_products_enrichment_columns(db)
        create_indexes(db)

        PingoDoce.logger.info "Database setup complete"
      end

      private

      def create_stores_table(db)
        db.create_table? :stores do
          primary_key :id
          String :external_id, unique: true, null: false
          String :name, null: false
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
        end
      end

      def create_brands_table(db)
        db.create_table? :brands do
          primary_key :id
          Integer :external_id
          String :name, null: false
          TrueClass :own_brand, default: false
          String :logo, text: true
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
        end
      end

      def create_transactions_table(db)
        db.create_table? :transactions do
          primary_key :id
          String :transaction_id, unique: true, null: false
          foreign_key :store_id, :stores, on_delete: :set_null
          Integer :total_items
          BigDecimal :total_discount, size: [10, 2]
          BigDecimal :total, size: [10, 2], null: false
          DateTime :transaction_date, null: false
          String :details, text: true
          DateTime :saved_at, default: Sequel::CURRENT_TIMESTAMP
        end
      end

      def create_products_table(db)
        db.create_table? :products do
          primary_key :id
          String :external_id
          String :name, null: false, text: true
          String :category, text: true
          Integer :category_id
          foreign_key :brand_id, :brands, on_delete: :set_null
          String :image, text: true
          DateTime :first_seen, null: false
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
        end
      end

      def create_purchases_table(db)
        db.create_table? :purchases do
          primary_key :id
          foreign_key :product_id, :products, on_delete: :cascade
          foreign_key :transaction_id, :transactions, on_delete: :cascade
          foreign_key :store_id, :stores, on_delete: :set_null
          BigDecimal :quantity, size: [10, 3]
          BigDecimal :price, size: [10, 2]
          BigDecimal :total, size: [10, 2]
          DateTime :purchase_date, null: false
        end
      end

      def create_product_nutritions_table(db)
        db.create_table? :product_nutritions do
          primary_key :id
          foreign_key :product_id, :products, on_delete: :cascade, unique: true
          Float :energy_kj
          Float :energy_kcal
          Float :fat
          Float :saturated_fat
          Float :carbohydrates
          Float :sugars
          Float :fiber
          Float :protein
          Float :salt
          DateTime :created_at, default: Sequel::CURRENT_TIMESTAMP
        end
      end

      def migrate_products_enrichment_columns(db)
        return unless db.table_exists?(:products)

        add_column_if_missing(db, :products, :ean, String)
        add_column_if_missing(db, :products, :description_html, String, text: true)
        add_column_if_missing(db, :products, :ingredients, String, text: true)
        add_column_if_missing(db, :products, :store_price, BigDecimal, size: [10, 2])
        add_column_if_missing(db, :products, :enrichment_status, String)
        add_column_if_missing(db, :products, :last_enriched_at, DateTime)
      end

      def add_column_if_missing(db, table, column, type, **opts)
        return if db.schema(table).any? { |col, _| col == column }

        db.alter_table(table) do
          add_column column, type, **opts
        end
      rescue Sequel::DatabaseError
        # Column might already exist
      end

      def create_indexes(db)
        add_index_if_missing(db, :transactions, :transaction_date)
        add_index_if_missing(db, :transactions, :store_id)
        add_index_if_missing(db, :products, :name)
        add_index_if_missing(db, :products, :external_id)
        add_index_if_missing(db, :products, :ean)
        add_index_if_missing(db, :products, :enrichment_status)
        add_index_if_missing(db, :purchases, :product_id)
        add_index_if_missing(db, :purchases, :transaction_id)
        add_index_if_missing(db, :purchases, :purchase_date)
        add_index_if_missing(db, :product_nutritions, :product_id)
      end

      def add_index_if_missing(db, table, column)
        return unless db.table_exists?(table)
        return if db.indexes(table).values.any? { |idx| idx[:columns] == [column] }

        db.add_index(table, column)
      rescue Sequel::DatabaseError
        # Index might already exist with different name
      end
    end
  end
end
