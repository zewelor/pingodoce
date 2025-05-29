#!/usr/bin/env ruby

require 'httparty'
require 'json'

class PingoDoceClient
  include HTTParty
  
  base_uri 'https://app.pingodoce.pt'
  
  def initialize
    @access_token = nil
    @user_profile = {}
    @headers = {
      'Content-Type' => 'application/json; charset=UTF-8',
      'Accept-Language' => 'en-US',
      'User-Agent' => 'okhttp/4.12.0',
      'X-App-Version' => 'v-3.12.4 buildType-release flavor-prod',
      'X-Device-Version' => 'Android-30',
      'X-Screen-Density' => '1.3312501',
      'Accept-Encoding' => 'gzip'
    }
  end
  
  def login(phone_number, password)
    puts "🔐 Logging in with phone number: #{phone_number}"
    
    # Login request payload
    login_data = {
      phoneNumber: phone_number,
      password: password
    }.to_json
    
    # Make login request
    response = self.class.post('/api/v2/identity/onboarding/login', 
      body: login_data,
      headers: @headers
    )
    
    if response.success?
      result = JSON.parse(response.body)
      @access_token = result['token']['access_token']
      @user_profile = result['profile']
      
      puts "✅ Login successful!"
      puts "   User: #{@user_profile['firstName']} #{@user_profile['lastName']}"
      puts "   Email: #{@user_profile['email']}"
      puts "   Loyalty ID: #{@user_profile['loyaltyId']}"
      puts "   Card Number: #{@user_profile['ompdCard']}"
      puts "   Household ID: #{@user_profile['householdId']}"
      
      # Update headers with authentication and user data
      update_authenticated_headers
      
      return true
    else
      puts "❌ Login failed! Status: #{response.code}"
      puts "   Response: #{response.body}"
      return false
    end
  rescue => e
    puts "❌ Login error: #{e.message}"
    return false
  end
  
  def get_transaction_history(page_number = 1, page_size = 20)
    unless @access_token
      puts "❌ Not authenticated. Please login first."
      return nil
    end
    
    puts "📊 Fetching transaction history (page #{page_number}, size #{page_size})..."
    
    response = self.class.get("/api/v2/user/transactionsHistory", 
      query: {
        pageNumber: page_number,
        pageSize: page_size
      },
      headers: @headers
    )
    
    if response.success?
      transactions = JSON.parse(response.body)
      puts "✅ Retrieved #{transactions.length rescue 'unknown'} transactions"
      return transactions
    else
      puts "❌ Failed to fetch transaction history. Status: #{response.code}"
      puts "   Response: #{response.body}"
      return nil
    end
  rescue => e
    puts "❌ Error fetching transaction history: #{e.message}"
    return nil
  end
  
  def get_transaction_details(transaction_id)
    unless @access_token
      puts "❌ Not authenticated. Please login first."
      return nil
    end
    
    puts "🔍 Fetching transaction details for ID: #{transaction_id}..."
    
    response = self.class.get("/api/v2/user/transactionsHistory/details", 
      query: { id: transaction_id },
      headers: @headers
    )
    
    if response.success?
      details = JSON.parse(response.body)
      puts "✅ Retrieved transaction details"
      return details
    else
      puts "❌ Failed to fetch transaction details. Status: #{response.code}"
      puts "   Response: #{response.body}"
      return nil
    end
  rescue => e
    puts "❌ Error fetching transaction details: #{e.message}"
    return nil
  end
  
  def pretty_print_transactions(transactions)
    return unless transactions.is_a?(Array)
    
    puts "\n📋 TRANSACTION HISTORY"
    puts "=" * 80
    
    transactions.each_with_index do |transaction, index|
      puts "\n#{index + 1}. Transaction Details:"
      puts "   Date: #{transaction['date'] || 'N/A'}"
      puts "   Store: #{transaction['storeName'] || 'N/A'}"
      puts "   Amount: #{transaction['total'] || 'N/A'}€"
      puts "   Items: #{transaction['itemCount'] || 'N/A'}"
      puts "   ID: #{transaction['id'] || 'N/A'}"
      puts "   Status: #{transaction['status'] || 'N/A'}"
    end
    
    puts "\n" + "=" * 80
  end
  
  private
  
  def update_authenticated_headers
    @headers.merge!({
      'Authorization' => "Bearer #{@access_token}",
      'Pdapp-Storeid' => '-1',
      'Pdapp-Cardnumber' => @user_profile['ompdCard'] || '',
      'Pdapp-Lcid' => @user_profile['loyaltyId'] || '',
      'Pdapp-Hid' => @user_profile['householdId'] || '',
      'Pdapp-Clubs' => ''
    })
  end
end

# Main execution
if __FILE__ == $0
  # Initialize client
  client = PingoDoceClient.new
  
  # Login credentials from the JSON data
  # Note: Replace these with your actual credentials
  phone_number = "+351"  # Replace with actual phone number
  password = ""              # Replace with actual password
  
  puts "🚀 Pingo Doce Transaction Fetcher"
  puts "=" * 50
  
  # Login
  if client.login(phone_number, password)
    
    # Fetch transaction history
    transactions = client.get_transaction_history(1, 10)
    
    if transactions
      # Pretty print the transactions
      client.pretty_print_transactions(transactions)
      
      # If there are transactions, get details for the first one
      if transactions.is_a?(Array) && transactions.length > 0 && transactions[0]['id']
        puts "\n🔍 Getting details for first transaction..."
        details = client.get_transaction_details(transactions[0]['id'])
        
        if details
          puts "\n📄 FIRST TRANSACTION DETAILS:"
          puts JSON.pretty_generate(details)
        end
      end
    end
    
  else
    puts "❌ Authentication failed. Please check your credentials."
  end
  
  puts "\n✨ Done!"
end
