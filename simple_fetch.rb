#!/usr/bin/env ruby

# Simple script that focuses only on login + transaction history
# Based on the HAR file from Pingo Doce app

require 'httparty'
require 'json'
require 'dotenv/load'

# Configuration - Loaded from .env file
PHONE_NUMBER = ENV.fetch('PHONE_NUMBER')
PASSWORD = ENV.fetch('PASSWORD')

# Validate environment variables
if PHONE_NUMBER == "+351..." || PASSWORD.empty?
  puts "❌ Please set PHONE_NUMBER and PASSWORD in your .env file"
  puts "   Example .env file:"
  puts "   PHONE_NUMBER=+351123456789"
  puts "   PASSWORD=your_password"
  exit 1
end

BASE_URL = "https://app.pingodoce.pt"

# Headers that match the mobile app requests
def get_headers(access_token = nil)
  headers = {
    'Content-Type' => 'application/json; charset=UTF-8',
    'Accept-Language' => 'en-US',
    'User-Agent' => 'okhttp/4.12.0',
    'X-App-Version' => 'v-3.12.4 buildType-release flavor-prod',
    'X-Device-Version' => 'Android-30',
    'X-Screen-Density' => '1.3312501'
  }

  if access_token
    headers['Authorization'] = "Bearer #{access_token}"
    # These values come from the user profile after login
    headers['Pdapp-Storeid'] = '-1'
    headers['Pdapp-Cardnumber'] = ''
    headers['Pdapp-Lcid'] = ''
    headers['Pdapp-Hid'] = ''
    headers['Pdapp-Clubs'] = ''
  end

  headers
end

# Step 1: Login to get access token
def login(phone_number, password)
  puts "🔐 Logging in..."

  login_data = {
    phoneNumber: phone_number,
    password: password
  }

  response = HTTParty.post(
    "#{BASE_URL}/api/v2/identity/onboarding/login",
    body: login_data.to_json,
    headers: get_headers
  )

  if response.success?
    result = JSON.parse(response.body)
    puts "✅ Login successful!"
    puts "   User: #{result['profile']['firstName']} #{result['profile']['lastName']}"

    # Return both token and profile for header setup
    return {
      access_token: result['token']['access_token'],
      profile: result['profile']
    }
  else
    puts "❌ Login failed: #{response.code} - #{response.body}"
    return nil
  end
rescue => e
  puts "❌ Login error: #{e.message}"
  return nil
end

# Step 2: Get transaction history
def get_transactions(auth_data, page = 1, size = 20)
  puts "📊 Fetching transaction history..."

  # Update headers with user profile data
  headers = get_headers(auth_data[:access_token])
  headers['Pdapp-Lcid'] = auth_data[:profile]['loyaltyId']
  headers['Pdapp-Hid'] = auth_data[:profile]['householdId']
  headers['Pdapp-Cardnumber'] = auth_data[:profile]['ompdCard'] || ''

  response = HTTParty.get(
    "#{BASE_URL}/api/v2/user/transactionsHistory",
    query: { pageNumber: page, pageSize: size },
    headers: headers
  )

  if response.success?
    transactions = JSON.parse(response.body)
    puts "✅ Retrieved transactions"
    return transactions
  else
    puts "❌ Failed to get transactions: #{response.code} - #{response.body}"
    return nil
  end
rescue => e
  puts "❌ Error: #{e.message}"
  return nil
end

# Step 3: Get latest transaction
def get_latest_transaction(auth_data)
  puts "🔍 Fetching latest transaction..."

  # Get just the first transaction (latest) by requesting page 1 with size 1
  transactions = get_transactions(auth_data, 1, 1)

  if transactions && transactions.is_a?(Array) && !transactions.empty?
    latest = transactions.first
    puts "✅ Latest transaction found:"
    puts "   Date: #{latest['transactionDate']}"
    puts "   Store: #{latest['storeName'] || 'N/A'}"
    puts "   Total: €#{latest['total'] || 'N/A'}"
    puts "   Items: #{latest['totalItems'] || 'N/A'} items"

    return latest
  else
    puts "❌ No transactions found"
    puts "   Response type: #{transactions.class}"
    puts "   Response: #{transactions.inspect}" if transactions
    return nil
  end
rescue => e
  puts "❌ Error getting latest transaction: #{e.message}"
  return nil
end

# Step 4: Get transaction details by ID
def get_transaction_details(auth_data, transaction_id, store_id = nil)
  puts "🔍 Fetching details for transaction #{transaction_id}..."

  # Update headers with user profile data
  headers = get_headers(auth_data[:access_token])
  headers['Pdapp-Lcid'] = auth_data[:profile]['loyaltyId']
  headers['Pdapp-Hid'] = auth_data[:profile]['householdId']
  headers['Pdapp-Cardnumber'] = auth_data[:profile]['ompdCard'] || ''
  
  # Use the store ID from the transaction if provided
  if store_id
    headers['Pdapp-Storeid'] = store_id.to_s
  end
  
  puts "   Using headers: #{headers.keys.join(', ')}"
  puts "   Store ID: #{headers['Pdapp-Storeid']}"
  puts "   Request URL: #{BASE_URL}/api/v2/user/transactionsHistory/details?id=#{transaction_id}"

  begin
    response = HTTParty.get(
      "#{BASE_URL}/api/v2/user/transactionsHistory/details",
      query: { id: transaction_id },
      headers: headers,
      timeout: 15
    )
  rescue Net::TimeoutError => e
    puts "❌ Request timed out: #{e.message}"
    return nil
  end

  if response.success?
    # Handle potential encoding issues
    response_body = response.body
    response_body = response_body.force_encoding('UTF-8') if response_body.encoding != Encoding::UTF_8
    
    details = JSON.parse(response_body)
    puts "✅ Transaction details retrieved"
    puts "   Transaction: #{details['transactionNumber']}"
    puts "   Store: #{details['storeName']}"
    puts "   Date: #{details['transactionDate']}"
    puts "   Products: #{details['products']&.length || 0} items"

    # Show product summary
    if details['products'] && !details['products'].empty?
      puts "\n📦 PRODUCTS PURCHASED:"
      details['products'].each_with_index do |product, index|
        quantity = product['purchaseQuantity']
        price = product['purchasePrice']
        name = product['name']
        image_url = product['image'] || product['thumb'] || 'No image'
        puts "   #{index + 1}. #{quantity}x #{name} - €#{price}"
        puts "      🖼️  Image: #{image_url}"
      end
    end

    return details
  else
    puts "❌ Failed to get transaction details: #{response.code} - #{response.body}"
    return nil
  end
rescue => e
  puts "❌ Error getting transaction details: #{e.message}"
  return nil
end

# Main execution
puts "🚀 Pingo Doce Transaction Fetcher (Simple Version)"
puts "=" * 60

# Step 1: Login
auth_data = login(PHONE_NUMBER, PASSWORD)

if auth_data
  # Step 2: Get latest transaction
  latest_transaction = get_latest_transaction(auth_data)

  if latest_transaction
    puts "\n📄 LATEST TRANSACTION SUMMARY:"
    puts JSON.pretty_generate(latest_transaction)

    # Step 3: Get detailed information for the latest transaction
    if latest_transaction['transactionId']
      transaction_details = get_transaction_details(auth_data, latest_transaction['transactionId'], latest_transaction['storeId'])

      if transaction_details
        puts "\n🛒 DETAILED TRANSACTION INFO:"
        puts JSON.pretty_generate(transaction_details)
      end
    end
  end

  # Optional: Get full transaction history (uncomment if needed)
  # puts "\n📋 FULL TRANSACTION HISTORY:"
  # transactions = get_transactions(auth_data)
  # if transactions
  #   puts JSON.pretty_generate(transactions)
  # end
else
  puts "❌ Cannot proceed without authentication"
end

puts "\n✨ Done!"
