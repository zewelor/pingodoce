# frozen_string_literal: true

require "httparty"
require "json"

module PingoDoce
  class Client
    include HTTParty

    BASE_URL = "https://app.pingodoce.pt"
    DEFAULT_PAGE_SIZE = 20

    ENDPOINTS = {
      login: "/api/v2/identity/onboarding/login",
      transactions: "/api/v2/user/transactionsHistory",
      transaction_details: "/api/v2/user/transactionsHistory/details",
      product_search: "/api/v2/catalog/search/products"
    }.freeze

    BASE_HEADERS = {
      "Content-Type" => "application/json; charset=UTF-8",
      "Accept-Language" => "en-US",
      "User-Agent" => "okhttp/4.12.0",
      "X-App-Version" => "v-3.12.4 buildType-release flavor-prod",
      "X-Device-Version" => "Android-30",
      "X-Screen-Density" => "1.3312501"
    }.freeze

    def initialize(phone_number: nil, password: nil, logger: nil)
      @phone_number = phone_number || PingoDoce.configuration.phone_number
      @password = password || PingoDoce.configuration.password
      @logger = logger || PingoDoce.logger
      @auth_data = nil
    end

    def login
      PingoDoce.configuration.validate!
      log_info "Logging in..."

      response = make_request(:post, ENDPOINTS[:login],
        body: login_payload.to_json,
        headers: BASE_HEADERS)

      process_login_response(response)
    end

    def transactions(page: 1, size: DEFAULT_PAGE_SIZE)
      ensure_authenticated!
      log_info "Fetching transactions (page: #{page}, size: #{size})..."

      response = make_request(:get, ENDPOINTS[:transactions],
        query: {pageNumber: page, pageSize: size},
        headers: authenticated_headers)

      result = JSON.parse(response.body)
      log_info "Retrieved #{result.length} transactions"
      result
    end

    def transaction_details(transaction_id, store_id: nil)
      ensure_authenticated!
      log_info "Fetching details for transaction #{transaction_id}..."

      response = make_request(:get, ENDPOINTS[:transaction_details],
        query: {id: transaction_id},
        headers: authenticated_headers(store_id))

      response_body = response.body
      response_body = response_body.force_encoding("UTF-8") if response_body.encoding != Encoding::UTF_8

      clean_response_data(JSON.parse(response_body))
    end

    def latest_transaction_with_details
      login unless authenticated?

      txns = transactions(page: 1, size: 1)
      return nil if txns.empty?

      transaction = txns.first
      details = transaction_details(
        transaction["transactionId"],
        store_id: transaction["storeId"]
      )

      {
        summary: clean_response_data(transaction),
        details: details
      }
    end

    def search_products(query, store_id:, page: 1, size: DEFAULT_PAGE_SIZE)
      ensure_authenticated!
      log_info "Searching products: '#{query}' (store: #{store_id}, page: #{page})..."

      response = make_request(:post, ENDPOINTS[:product_search],
        body: {storeId: store_id, text: query, page: page, size: size}.to_json,
        headers: authenticated_headers(store_id))

      result = JSON.parse(response.body)
      log_info "Found #{result["totalHits"]} products"
      result
    end

    def lookup_barcode(ean, store_id:)
      ensure_authenticated!
      log_info "Looking up barcode: #{ean}..."

      response = make_request(:post, ENDPOINTS[:product_search],
        body: {storeId: store_id, barcode: ean, page: 1, size: 1}.to_json,
        headers: authenticated_headers(store_id))

      result = JSON.parse(response.body)
      documents = result["documents"] || []

      if documents.any?
        log_info "Found product: #{documents.first["name"]}"
        documents.first
      else
        log_info "Product not found for barcode: #{ean}"
        nil
      end
    end

    def fetch_product_by_code(product_code, store_id:)
      ensure_authenticated!

      response = make_request(:post, ENDPOINTS[:product_search],
        body: {storeId: store_id, text: product_code.to_s, page: 1, size: 10}.to_json,
        headers: authenticated_headers(store_id))

      result = JSON.parse(response.body)
      documents = result["documents"] || []

      documents.find { |p| p["productInternalCode"].to_s == product_code.to_s }
    end

    def authenticated?
      !@auth_data&.dig(:access_token).nil?
    end

    private

    attr_reader :logger

    def log_info(message)
      logger.info(message)
    end

    def ensure_authenticated!
      raise NotAuthenticatedError, "Not authenticated. Call login first." unless authenticated?
    end

    def make_request(method, endpoint, options = {})
      url = "#{BASE_URL}#{endpoint}"
      options = options.merge(timeout: PingoDoce.configuration.timeout)

      response = self.class.send(method, url, options)

      unless response.success?
        raise APIError, "#{method.upcase} #{endpoint} failed: #{response.code} - #{response.body}"
      end

      response
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise APIError, "Request timed out: #{e.message}"
    end

    def login_payload
      {phoneNumber: @phone_number, password: @password}
    end

    def process_login_response(response)
      result = JSON.parse(response.body)
      profile = result["profile"]

      @auth_data = {
        access_token: result.dig("token", "access_token"),
        profile: profile
      }

      log_info "Login successful! User: #{profile["firstName"]} #{profile["lastName"]}"
      @auth_data
    end

    def authenticated_headers(store_id = nil)
      BASE_HEADERS.merge(auth_headers(store_id))
    end

    def auth_headers(store_id = nil)
      profile = @auth_data[:profile]

      {
        "Authorization" => "Bearer #{@auth_data[:access_token]}",
        "Pdapp-Storeid" => store_id&.to_s || "-1",
        "Pdapp-Cardnumber" => profile["ompdCard"] || "",
        "Pdapp-Lcid" => profile["loyaltyId"] || "",
        "Pdapp-Hid" => profile["householdId"] || "",
        "Pdapp-Clubs" => ""
      }
    end

    def clean_response_data(data)
      case data
      when Hash
        data.transform_values { |value| clean_response_data(value) }
      when Array
        data.map { |item| clean_response_data(item) }
      when String
        cleaned = data.gsub(/[\n\r]+/, "").strip
        if cleaned.match?(%r{^https?://})
          cleaned.gsub(/\s+/, "")
        else
          cleaned.gsub(/\s+/, " ")
        end
      else
        data
      end
    end
  end
end
