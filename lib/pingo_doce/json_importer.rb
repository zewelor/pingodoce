# frozen_string_literal: true

require "json"

module PingoDoce
  class JsonImporter
    def initialize(storage: nil, logger: nil)
      @logger = logger || PingoDoce.logger
      @storage = storage || Storage.new(logger: @logger)
    end

    def import(json_dir:)
      transactions_file = File.join(json_dir, "transactions.json")

      unless File.exist?(transactions_file)
        raise StorageError, "transactions.json not found in #{json_dir}"
      end

      transactions = JSON.parse(File.read(transactions_file))

      result = {
        transactions: 0,
        products: 0,
        skipped: 0
      }

      transactions.each do |transaction_id, data|
        if @storage.transaction_exists?(transaction_id)
          result[:skipped] += 1
          next
        end

        details = data["details"]
        products_count = details&.dig("products")&.length || 0

        @storage.save_transaction(data, details)

        result[:transactions] += 1
        result[:products] += products_count

        @logger.info "Imported: #{transaction_id} (#{products_count} products)"
      end

      @logger.info "Import finished: #{result[:transactions]} transactions, #{result[:products]} products, #{result[:skipped]} skipped"

      result
    end
  end
end
