# frozen_string_literal: true

module PingoDoce
  class ProductEnricher
    def initialize(client:, storage:, store_id:, logger: nil)
      @client = client
      @storage = storage
      @store_id = store_id
      @logger = logger || PingoDoce.logger
    end

    def enrich(product)
      log_info "Enriching product: #{product[:name]}"

      catalog_data = find_in_catalog(product)

      if catalog_data
        @storage.enrich_product(product[:id], catalog_data)
        log_info "  -> Enriched with EAN: #{catalog_data["ean"]}"
        true
      else
        @storage.mark_product_unavailable(product[:id])
        log_info "  -> Not found in catalog"
        false
      end
    rescue APIError => e
      log_info "  -> API error: #{e.message}"
      false
    end

    def enrich_batch(products, delay: 0.5)
      results = {enriched: 0, not_found: 0, errors: 0}
      return results if products.empty?

      log_info "Enriching #{products.length} products..."

      products.each_with_index do |product, index|
        sleep(delay) if index > 0

        begin
          if enrich(product)
            results[:enriched] += 1
          else
            results[:not_found] += 1
          end
        rescue => e
          log_info "  -> Error enriching #{product[:name]}: #{e.message}"
          results[:errors] += 1
        end
      end

      log_info "Enrichment complete: #{results[:enriched]} enriched, " \
               "#{results[:not_found]} not found, #{results[:errors]} errors"

      results
    end

    private

    attr_reader :logger

    def log_info(message)
      logger.info(message)
    end

    def find_in_catalog(product)
      # Strategy 1: Search by external_id (productInternalCode)
      if product[:external_id]
        result = @client.fetch_product_by_code(product[:external_id], store_id: @store_id)
        return result if result
      end

      # Strategy 2: Search by name
      results = @client.search_products(product[:name], store_id: @store_id, page: 1, size: 5)
      documents = results["documents"] || []

      # Find best match by name similarity
      find_best_match(documents, product[:name])
    end

    def find_best_match(documents, target_name)
      return nil if documents.empty?

      target_normalized = normalize_name(target_name)

      # First try exact match
      exact = documents.find { |doc| normalize_name(doc["name"]) == target_normalized }
      return exact if exact

      # Then try partial match (target contained in doc name or vice versa)
      partial = documents.find do |doc|
        doc_normalized = normalize_name(doc["name"])
        doc_normalized.include?(target_normalized) || target_normalized.include?(doc_normalized)
      end
      return partial if partial

      # If only one result and names are similar enough, use it
      if documents.length == 1
        similarity = calculate_similarity(target_normalized, normalize_name(documents.first["name"]))
        return documents.first if similarity > 0.6
      end

      nil
    end

    def normalize_name(name)
      name.to_s.downcase
        .gsub(/[^\p{L}\p{N}\s]/, "") # Remove punctuation but keep accented chars
        .gsub(/\s+/, " ")
        .strip
    end

    def calculate_similarity(str1, str2)
      return 1.0 if str1 == str2
      return 0.0 if str1.empty? || str2.empty?

      # Simple word overlap similarity
      words1 = str1.split
      words2 = str2.split

      common = (words1 & words2).length
      total = [words1.length, words2.length].max

      common.to_f / total
    end
  end
end
