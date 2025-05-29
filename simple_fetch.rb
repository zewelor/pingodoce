#!/usr/bin/env ruby

# Simple script that focuses only on login + transaction history
# Based on the HAR file from Pingo Doce app

require 'httparty'
require 'json'

# Configuration - UPDATE THESE WITH YOUR CREDENTIALS
PHONE_NUMBER = "+351..."  # Replace with your phone number
PASSWORD = ""             # Replace with your password

BASE_URL = "https://app.pingodoce.pt"

# Headers that match the mobile app requests
def get_headers(access_token = nil)
  headers = {
    'Content-Type' => 'application/json; charset=UTF-8',
    'Accept-Language' => 'en-US', 
    'User-Agent' => 'okhttp/4.12.0',
    'X-App-Version' => 'v-3.12.4 buildType-release flavor-prod',
    'X-Device-Version' => 'Android-30',
    'X-Screen-Density' => '1.3312501',
    'Accept-Encoding' => 'gzip'
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

# Main execution
puts "🚀 Pingo Doce Transaction Fetcher (Simple Version)"
puts "=" * 60

# Step 1: Login
auth_data = login(PHONE_NUMBER, PASSWORD)

if auth_data
  # Step 2: Get transactions
  transactions = get_transactions(auth_data)
  
  if transactions
    puts "\n📋 TRANSACTION HISTORY:"
    puts JSON.pretty_generate(transactions)
  end
else
  puts "❌ Cannot proceed without authentication"
end

puts "\n✨ Done!"
