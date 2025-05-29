#!/usr/bin/env ruby
# frozen_string_literal: true

# Improved Pingo Doce API Client
# Follows Ruby best practices and DRY principles

require 'httparty'
require 'json'
require 'dotenv/load'
require 'timeout'

class PingoDoceClient
  include HTTParty

  # Constants
  BASE_URL = 'https://app.pingodoce.pt'
  DEFAULT_TIMEOUT = 15
  DEFAULT_PAGE_SIZE = 20

  # API Endpoints
  ENDPOINTS = {
    login: '/api/v2/identity/onboarding/login',
    transactions: '/api/v2/user/transactionsHistory',
    transaction_details: '/api/v2/user/transactionsHistory/details'
  }.freeze

  # Common headers for all requests
  BASE_HEADERS = {
    'Content-Type' => 'application/json; charset=UTF-8',
    'Accept-Language' => 'en-US',
    'User-Agent' => 'okhttp/4.12.0',
    'X-App-Version' => 'v-3.12.4 buildType-release flavor-prod',
    'X-Device-Version' => 'Android-30',
    'X-Screen-Density' => '1.3312501'
  }.freeze

  class AuthenticationError < StandardError; end
  class APIError < StandardError; end

  def initialize(phone_number: nil, password: nil)
    @phone_number = phone_number || ENV.fetch('PHONE_NUMBER')
    @password = password || ENV.fetch('PASSWORD')
    @auth_data = nil

    validate_credentials!
  end

  # Public API methods

  def login
    log_info '🔐 Logging in...'

    response = make_request(:post, ENDPOINTS[:login], {
      body: login_payload.to_json,
      headers: BASE_HEADERS
    })

    process_login_response(response)
  end

  def latest_transaction
    ensure_authenticated!

    log_info '🔍 Fetching latest transaction...'
    transactions = get_transactions(page: 1, size: 1)

    return nil if transactions.empty?

    transaction = transactions.first
    log_transaction_summary(transaction)
    transaction
  end

  def transaction_details(transaction_id, store_id = nil)
    ensure_authenticated!

    log_info "🔍 Fetching details for transaction #{transaction_id}..."

    response = make_request(:get, ENDPOINTS[:transaction_details], {
      query: { id: transaction_id },
      headers: authenticated_headers(store_id)
    })

    # Handle potential encoding issues and clean up the response
    response_body = response.body
    response_body = response_body.force_encoding('UTF-8') if response_body.encoding != Encoding::UTF_8

    details = JSON.parse(response_body)
    details = clean_response_data(details)
    log_transaction_details(details)
    details
  end

  def transactions(page: 1, size: DEFAULT_PAGE_SIZE)
    ensure_authenticated!
    get_transactions(page: page, size: size)
  end

  # Main workflow method
  def fetch_latest_with_details
    login unless authenticated?

    transaction = latest_transaction
    return nil unless transaction&.dig('transactionId')

    details = transaction_details(
      transaction['transactionId'],
      transaction['storeId']
    )

    # Return cleaned data
    {
      summary: clean_response_data(transaction),
      details: clean_response_data(details)
    }
  end

  # Public method to clean data for external use
  def clean_data(data)
    clean_response_data(data)
  end

  private

  # Authentication helpers

  def validate_credentials!
    if @phone_number == '+351...' || @password.empty?
      raise AuthenticationError, credential_error_message
    end
  end

  def login_payload
    {
      phoneNumber: @phone_number,
      password: @password
    }
  end

  def process_login_response(response)
    result = JSON.parse(response.body)
    profile = result['profile']

    @auth_data = {
      access_token: result.dig('token', 'access_token'),
      profile: profile
    }

    log_info "✅ Login successful! User: #{profile['firstName']} #{profile['lastName']}"
    @auth_data
  end

  def authenticated?
    @auth_data&.dig(:access_token)
  end

  def ensure_authenticated!
    raise AuthenticationError, 'Not authenticated. Call login first.' unless authenticated?
  end

  # HTTP request helpers

  def make_request(method, endpoint, options = {})
    url = "#{BASE_URL}#{endpoint}"
    options = options.merge(timeout: DEFAULT_TIMEOUT)

    response = self.class.send(method, url, options)

    unless response.success?
      raise APIError, "#{method.upcase} #{endpoint} failed: #{response.code} - #{response.body}"
    end

    response
  rescue Timeout::Error, Net::TimeoutError => e
    raise APIError, "Request timed out: #{e.message}"
  rescue => e
    raise APIError, "Request failed: #{e.message}"
  end

  def get_transactions(page:, size:)
    log_info '📊 Fetching transaction history...'

    response = make_request(:get, ENDPOINTS[:transactions], {
      query: { pageNumber: page, pageSize: size },
      headers: authenticated_headers
    })

    transactions = JSON.parse(response.body)
    log_info "✅ Retrieved #{transactions.length} transactions"
    transactions
  end

  # Header builders

  def authenticated_headers(store_id = nil)
    BASE_HEADERS.merge(auth_headers(store_id))
  end

  def auth_headers(store_id = nil)
    profile = @auth_data[:profile]

    {
      'Authorization' => "Bearer #{@auth_data[:access_token]}",
      'Pdapp-Storeid' => store_id&.to_s || '-1',
      'Pdapp-Cardnumber' => profile['ompdCard'] || '',
      'Pdapp-Lcid' => profile['loyaltyId'] || '',
      'Pdapp-Hid' => profile['householdId'] || '',
      'Pdapp-Clubs' => ''
    }
  end

  # Data cleaning helpers

  def clean_response_data(data)
    case data
    when Hash
      data.transform_values { |value| clean_response_data(value) }
    when Array
      data.map { |item| clean_response_data(item) }
    when String
      # Clean URLs and other strings - remove newlines and normalize whitespace
      cleaned = data.gsub(/\n+/, '').gsub(/\r+/, '').strip
      # Additional cleaning for URLs
      if cleaned.match?(/^https?:\/\//)
        cleaned.gsub(/\s+/, '')
      else
        cleaned.gsub(/\s+/, ' ')
      end
    else
      data
    end
  end

  # Logging and display helpers

  def log_info(message)
    puts message
  end

  def log_transaction_summary(transaction)
    log_info '✅ Latest transaction found:'
    log_info "   Date: #{transaction['transactionDate']}"
    log_info "   Store: #{transaction['storeName'] || 'N/A'}"
    log_info "   Total: €#{transaction['total'] || 'N/A'}"
    log_info "   Items: #{transaction['totalItems'] || 'N/A'} items"
  end

  def log_transaction_details(details)
    log_info '✅ Transaction details retrieved'
    log_info "   Transaction: #{details['transactionNumber']}"
    log_info "   Store: #{details['storeName']}"
    log_info "   Date: #{details['transactionDate']}"

    products = details['products'] || []
    log_info "   Products: #{products.length} items"

    log_products(products) if products.any?
  end

  def log_products(products)
    log_info "\n📦 PRODUCTS PURCHASED:"

    products.each_with_index do |product, index|
      quantity = product['purchaseQuantity']
      price = product['purchasePrice']
      name = product['name']
      image_url = product['image'] || product['thumb'] || 'No image'

      log_info "   #{index + 1}. #{quantity}x #{name} - €#{price}"
      log_info "      🖼️  Image: #{image_url}"
    end
  end

  def credential_error_message
    <<~MSG
      ❌ Please set PHONE_NUMBER and PASSWORD in your .env file
         Example .env file:
         PHONE_NUMBER=+351123456789
         PASSWORD=your_password
    MSG
  end
end

# Usage example / CLI interface
if __FILE__ == $0
  puts '🚀 Pingo Doce Transaction Fetcher (Improved Version)'
  puts '=' * 60

  begin
    client = PingoDoceClient.new
    result = client.fetch_latest_with_details

    if result
      puts "\n📄 LATEST TRANSACTION SUMMARY:"
      puts JSON.pretty_generate(result[:summary])

      if result[:details]
        puts "\n🛒 DETAILED TRANSACTION INFO:"
        puts JSON.pretty_generate(result[:details])
      end
    else
      puts '❌ No transactions found'
    end

  rescue PingoDoceClient::AuthenticationError => e
    puts "❌ Authentication Error: #{e.message}"
    exit 1
  rescue PingoDoceClient::APIError => e
    puts "❌ API Error: #{e.message}"
    exit 1
  rescue => e
    puts "❌ Unexpected Error: #{e.message}"
    puts e.backtrace.first(5).join("\n") if ENV['DEBUG']
    exit 1
  end

  puts "\n✨ Done!"
end
