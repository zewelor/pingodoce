# frozen_string_literal: true

require "cgi"

module PingoDoce
  class NutritionParser
    PATTERNS = {
      energy: /Energia:\s*([\d,.]+)\s*kj\s*\/\s*([\d,.]+)\s*kcal/i,
      fat: /L[ií]pidos:\s*([\d,.]+)\s*g/i,
      saturated_fat: /(?:Dos quais )?saturados:\s*([\d,.]+)\s*g/i,
      carbohydrates: /Hidratos de carbono:\s*([\d,.]+)\s*g/i,
      sugars: /(?:Dos quais )?a[çc][úu]cares:\s*([\d,.]+)\s*g/i,
      fiber: /Fibras?:\s*([\d,.]+)\s*g/i,
      protein: /Prote[ií]nas?:\s*([\d,.]+)\s*g/i,
      salt: /Sal:\s*([\d,.]+)\s*g/i
    }.freeze

    class << self
      def parse(html)
        return empty_result if html.nil? || html.empty?

        text = html_to_text(html)

        {
          energy_kj: extract_energy_kj(text),
          energy_kcal: extract_energy_kcal(text),
          fat: extract_value(text, PATTERNS[:fat]),
          saturated_fat: extract_value(text, PATTERNS[:saturated_fat]),
          carbohydrates: extract_value(text, PATTERNS[:carbohydrates]),
          sugars: extract_value(text, PATTERNS[:sugars]),
          fiber: extract_value(text, PATTERNS[:fiber]),
          protein: extract_value(text, PATTERNS[:protein]),
          salt: extract_value(text, PATTERNS[:salt]),
          ingredients: extract_ingredients(text)
        }
      end

      def has_nutrition_data?(html)
        return false if html.nil? || html.empty?

        text = html_to_text(html)
        text.include?("Nutri") || text.include?("Energia") || text.include?("kcal")
      end

      private

      def html_to_text(html)
        text = html.dup
        text.gsub!(/<br\s*\/?>/i, "\n")
        text.gsub!(/<[^>]+>/, " ")
        text = CGI.unescapeHTML(text)
        text.gsub!(/\s+/, " ")
        text.strip
      end

      def extract_energy_kj(text)
        match = text.match(PATTERNS[:energy])
        return nil unless match

        parse_decimal(match[1])
      end

      def extract_energy_kcal(text)
        match = text.match(PATTERNS[:energy])
        return nil unless match

        parse_decimal(match[2])
      end

      def extract_value(text, pattern)
        match = text.match(pattern)
        return nil unless match

        parse_decimal(match[1])
      end

      def extract_ingredients(text)
        match = text.match(/Ingredientes[:\s]*(.+?)(?:\z|Alerg|Conservar|Pode conter)/im)
        return nil unless match

        ingredients = match[1].strip
        ingredients.gsub!(/\s+/, " ")
        ingredients.gsub!(/\.$/, "")
        ingredients.empty? ? nil : ingredients
      end

      def parse_decimal(value)
        return nil if value.nil? || value.empty?

        value.tr(",", ".").to_f
      end

      def empty_result
        {
          energy_kj: nil,
          energy_kcal: nil,
          fat: nil,
          saturated_fat: nil,
          carbohydrates: nil,
          sugars: nil,
          fiber: nil,
          protein: nil,
          salt: nil,
          ingredients: nil
        }
      end
    end
  end
end
