# frozen_string_literal: true

require "spec_helper"

RSpec.describe PingoDoce::NutritionParser do
  describe ".parse" do
    context "with valid Portuguese nutrition HTML" do
      let(:html) do
        <<~HTML
          <p>Informação Nutricional por 100g:</p>
          <p>Energia: 435 kj / 103 kcal</p>
          <p>Lípidos: 2,5 g</p>
          <p>Dos quais saturados: 0,4 g</p>
          <p>Hidratos de carbono: 12,8 g</p>
          <p>Dos quais açúcares: 4,5 g</p>
          <p>Fibras: 1,2 g</p>
          <p>Proteínas: 6,3 g</p>
          <p>Sal: 0,75 g</p>
          <p>Ingredientes: Farinha de trigo, água, sal, levedura</p>
        HTML
      end

      it "parses energy values" do
        result = described_class.parse(html)

        expect(result[:energy_kj]).to eq(435.0)
        expect(result[:energy_kcal]).to eq(103.0)
      end

      it "parses fat values" do
        result = described_class.parse(html)

        expect(result[:fat]).to eq(2.5)
        expect(result[:saturated_fat]).to eq(0.4)
      end

      it "parses carbohydrates and sugars" do
        result = described_class.parse(html)

        expect(result[:carbohydrates]).to eq(12.8)
        expect(result[:sugars]).to eq(4.5)
      end

      it "parses fiber, protein, and salt" do
        result = described_class.parse(html)

        expect(result[:fiber]).to eq(1.2)
        expect(result[:protein]).to eq(6.3)
        expect(result[:salt]).to eq(0.75)
      end

      it "extracts ingredients" do
        result = described_class.parse(html)

        expect(result[:ingredients]).to include("Farinha de trigo")
        expect(result[:ingredients]).to include("levedura")
      end
    end

    context "with HTML containing <br> tags" do
      let(:html) do
        "Energia: 200 kj / 48 kcal<br/>Lípidos: 1,0 g<br>Proteínas: 3,5 g"
      end

      it "handles br tags correctly" do
        result = described_class.parse(html)

        expect(result[:energy_kcal]).to eq(48.0)
        expect(result[:fat]).to eq(1.0)
        expect(result[:protein]).to eq(3.5)
      end
    end

    context "with European decimal format" do
      let(:html) { "Energia: 1234 kj / 295 kcal<br/>Lípidos: 12,35 g" }

      it "converts comma to decimal point" do
        result = described_class.parse(html)

        expect(result[:fat]).to eq(12.35)
      end
    end

    context "with nil input" do
      it "returns empty result" do
        result = described_class.parse(nil)

        expect(result[:energy_kcal]).to be_nil
        expect(result[:protein]).to be_nil
        expect(result[:ingredients]).to be_nil
      end
    end

    context "with empty string" do
      it "returns empty result" do
        result = described_class.parse("")

        expect(result[:energy_kcal]).to be_nil
        expect(result[:protein]).to be_nil
      end
    end

    context "with non-food product description" do
      let(:html) { "<p>Produto de limpeza. Manter fora do alcance das crianças.</p>" }

      it "returns empty nutrition values" do
        result = described_class.parse(html)

        expect(result[:energy_kcal]).to be_nil
        expect(result[:protein]).to be_nil
        expect(result[:fat]).to be_nil
      end
    end
  end

  describe ".has_nutrition_data?" do
    it "returns true for nutrition content" do
      expect(described_class.has_nutrition_data?("Energia: 100 kcal")).to be true
      expect(described_class.has_nutrition_data?("Informação Nutricional")).to be true
    end

    it "returns false for non-nutrition content" do
      expect(described_class.has_nutrition_data?("Produto de limpeza")).to be false
    end

    it "returns false for nil" do
      expect(described_class.has_nutrition_data?(nil)).to be false
    end

    it "returns false for empty string" do
      expect(described_class.has_nutrition_data?("")).to be false
    end
  end
end
