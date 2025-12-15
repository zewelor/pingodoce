# frozen_string_literal: true

require "spec_helper"

RSpec.describe PingoDoce::Client do
  let(:client) { described_class.new }

  let(:login_response) do
    {
      token: {access_token: "test_token_123"},
      profile: {
        firstName: "Test",
        lastName: "User",
        loyaltyId: "L123",
        ompdCard: "C456",
        householdId: "H789"
      }
    }
  end

  let(:transactions_response) do
    [
      {
        "transactionId" => "TXN001",
        "transactionDate" => "2024-01-15",
        "storeName" => "Pingo Doce Lisboa",
        "storeId" => "STORE001",
        "total" => 45.50,
        "totalItems" => 10
      }
    ]
  end

  let(:transaction_details_response) do
    {
      "transactionId" => "TXN001",
      "transactionNumber" => "12345",
      "transactionDate" => "2024-01-15",
      "storeName" => "Pingo Doce Lisboa",
      "storeId" => "STORE001",
      "total" => 45.50,
      "products" => [
        {
          "productId" => "P001",
          "name" => "Milk 1L",
          "category" => "Dairy",
          "brand" => "Mimosa",
          "purchaseQuantity" => 2,
          "purchasePrice" => 1.29,
          "totalAmount" => 2.58
        }
      ]
    }
  end

  describe "#login" do
    it "authenticates successfully with valid credentials" do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .with(
          body: {phoneNumber: "+351123456789", password: "testpassword"}.to_json,
          headers: {"Content-Type" => "application/json; charset=UTF-8"}
        )
        .to_return(status: 200, body: login_response.to_json)

      result = client.login

      expect(result[:access_token]).to eq("test_token_123")
      expect(client.authenticated?).to be true
    end

    it "raises APIError on failed login" do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .to_return(status: 401, body: "Unauthorized")

      expect { client.login }.to raise_error(PingoDoce::APIError, /failed: 401/)
    end

    it "raises APIError on timeout" do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .to_timeout

      expect { client.login }.to raise_error(PingoDoce::APIError, /timed out/)
    end
  end

  describe "#transactions" do
    before do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .to_return(status: 200, body: login_response.to_json)
      client.login
    end

    it "fetches transactions successfully" do
      stub_request(:get, "https://app.pingodoce.pt/api/v2/user/transactionsHistory")
        .with(query: {pageNumber: 1, pageSize: 10})
        .to_return(status: 200, body: transactions_response.to_json)

      result = client.transactions(page: 1, size: 10)

      expect(result.length).to eq(1)
      expect(result.first["transactionId"]).to eq("TXN001")
    end

    it "raises NotAuthenticatedError when not authenticated" do
      new_client = described_class.new
      expect { new_client.transactions }.to raise_error(PingoDoce::NotAuthenticatedError)
    end
  end

  describe "#transaction_details" do
    before do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .to_return(status: 200, body: login_response.to_json)
      client.login
    end

    it "fetches transaction details successfully" do
      stub_request(:get, "https://app.pingodoce.pt/api/v2/user/transactionsHistory/details")
        .with(query: {id: "TXN001"})
        .to_return(status: 200, body: transaction_details_response.to_json)

      result = client.transaction_details("TXN001")

      expect(result["transactionId"]).to eq("TXN001")
      expect(result["products"].length).to eq(1)
      expect(result["products"].first["name"]).to eq("Milk 1L")
    end
  end

  describe "#latest_transaction_with_details" do
    it "fetches latest transaction and its details" do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .to_return(status: 200, body: login_response.to_json)

      stub_request(:get, "https://app.pingodoce.pt/api/v2/user/transactionsHistory")
        .with(query: {pageNumber: 1, pageSize: 1})
        .to_return(status: 200, body: transactions_response.to_json)

      stub_request(:get, "https://app.pingodoce.pt/api/v2/user/transactionsHistory/details")
        .with(query: {id: "TXN001"})
        .to_return(status: 200, body: transaction_details_response.to_json)

      result = client.latest_transaction_with_details

      expect(result[:summary]["transactionId"]).to eq("TXN001")
      expect(result[:details]["products"].first["name"]).to eq("Milk 1L")
    end

    it "returns nil when no transactions exist" do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .to_return(status: 200, body: login_response.to_json)

      stub_request(:get, "https://app.pingodoce.pt/api/v2/user/transactionsHistory")
        .with(query: {pageNumber: 1, pageSize: 1})
        .to_return(status: 200, body: [].to_json)

      result = client.latest_transaction_with_details

      expect(result).to be_nil
    end
  end

  describe "#authenticated?" do
    it "returns false before login" do
      expect(client.authenticated?).to be false
    end

    it "returns true after successful login" do
      stub_request(:post, "https://app.pingodoce.pt/api/v2/identity/onboarding/login")
        .to_return(status: 200, body: login_response.to_json)

      client.login
      expect(client.authenticated?).to be true
    end
  end
end
