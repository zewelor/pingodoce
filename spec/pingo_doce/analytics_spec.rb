# frozen_string_literal: true

require "spec_helper"

RSpec.describe PingoDoce::Analytics do
  let(:analytics) { described_class.new(data_dir: "tmp/test_data") }

  let(:transaction_data) do
    {
      "transactionId" => "TXN001",
      "transactionDate" => Date.today.to_s,
      "storeName" => "Pingo Doce Lisboa",
      "storeId" => "STORE001",
      "total" => 45.50,
      "totalItems" => 3
    }
  end

  let(:transaction_details) do
    {
      "transactionId" => "TXN001",
      "products" => [
        {
          "productId" => "P001",
          "name" => "Milk 1L",
          "category" => "Dairy",
          "brand" => "Mimosa",
          "purchaseQuantity" => 2,
          "purchasePrice" => 1.29,
          "totalAmount" => 2.58
        },
        {
          "productId" => "P002",
          "name" => "Bread",
          "category" => "Bakery",
          "brand" => "Local",
          "purchaseQuantity" => 1,
          "purchasePrice" => 0.89,
          "totalAmount" => 0.89
        }
      ]
    }
  end

  describe "#save_transaction" do
    it "saves a transaction to the database" do
      analytics.save_transaction(transaction_data, transaction_details)

      expect(analytics.transaction_exists?("TXN001")).to be true
    end

    it "saves products from the transaction" do
      analytics.save_transaction(transaction_data, transaction_details)
      stats = analytics.stats

      expect(stats[:total_products]).to eq(2)
    end
  end

  describe "#spending_report" do
    it "returns empty report when no transactions exist" do
      report = analytics.spending_report(days: 30)

      expect(report[:message]).to include("No transactions found")
    end

    it "calculates spending correctly" do
      analytics.save_transaction(transaction_data, transaction_details)
      report = analytics.spending_report(days: 30)

      expect(report[:total_spent]).to eq(45.50)
      expect(report[:transaction_count]).to eq(1)
      expect(report[:average_per_transaction]).to eq(45.50)
    end

    it "groups spending by store" do
      analytics.save_transaction(transaction_data, transaction_details)
      report = analytics.spending_report(days: 30)

      expect(report[:by_store]["Pingo Doce Lisboa"]).to eq(45.50)
    end
  end

  describe "#price_trends" do
    it "returns empty array when no products have multiple purchases" do
      analytics.save_transaction(transaction_data, transaction_details)
      trends = analytics.price_trends

      expect(trends).to be_empty
    end

    it "calculates price trends for products with multiple purchases" do
      # First purchase
      analytics.save_transaction(transaction_data, transaction_details)

      # Second purchase with price change
      second_transaction = transaction_data.merge(
        "transactionId" => "TXN002",
        "transactionDate" => (Date.today + 7).to_s
      )
      second_details = {
        "transactionId" => "TXN002",
        "products" => [
          {
            "productId" => "P001",
            "name" => "Milk 1L",
            "category" => "Dairy",
            "brand" => "Mimosa",
            "purchaseQuantity" => 1,
            "purchasePrice" => 1.49,
            "totalAmount" => 1.49
          }
        ]
      }
      analytics.save_transaction(second_transaction, second_details)

      trends = analytics.price_trends

      expect(trends.length).to eq(1)
      expect(trends.first[:name]).to eq("Milk 1L")
      expect(trends.first[:price_change]).to eq(0.20)
    end
  end

  describe "#stats" do
    it "returns empty stats when no data" do
      stats = analytics.stats

      expect(stats[:total_transactions]).to eq(0)
      expect(stats[:total_products]).to eq(0)
      expect(stats[:total_spent]).to eq(0)
    end

    it "returns correct stats after saving transactions" do
      analytics.save_transaction(transaction_data, transaction_details)
      stats = analytics.stats

      expect(stats[:total_transactions]).to eq(1)
      expect(stats[:total_products]).to eq(2)
      expect(stats[:total_spent]).to eq(45.50)
    end
  end

  describe "#export_csv" do
    it "exports transactions and products to CSV" do
      analytics.save_transaction(transaction_data, transaction_details)
      analytics.export_csv

      expect(File.exist?("tmp/test_data/transactions.csv")).to be true
      expect(File.exist?("tmp/test_data/products.csv")).to be true
    end
  end

  describe "#transaction_exists?" do
    it "returns false for non-existent transaction" do
      expect(analytics.transaction_exists?("FAKE")).to be false
    end

    it "returns true for existing transaction" do
      analytics.save_transaction(transaction_data, transaction_details)
      expect(analytics.transaction_exists?("TXN001")).to be true
    end
  end

  describe "#get_transaction" do
    it "returns nil for non-existent transaction" do
      expect(analytics.get_transaction("FAKE")).to be_nil
    end

    it "returns transaction data for existing transaction" do
      analytics.save_transaction(transaction_data, transaction_details)
      result = analytics.get_transaction("TXN001")

      expect(result["transactionId"]).to eq("TXN001")
      expect(result["total"]).to eq(45.50)
    end
  end
end
