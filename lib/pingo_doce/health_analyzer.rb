# frozen_string_literal: true

module PingoDoce
  class HealthAnalyzer
    # Keywords include variants:
    # - With and without Portuguese accents (ã, á, é, í, ó, ú, ç)
    # - Common typos and abbreviations
    # - Both singular and common forms

    # Protein sources (plant-based + dairy for vegetarians)
    PROTEIN_KEYWORDS = %w[
      proteic protein proteín proteina prot
      tofu seitan tempeh
      skyr yopro goactive quark
      ovo ovos egg eggs
    ].freeze

    # Fermented/probiotic foods
    FERMENTED_KEYWORDS = %w[
      kefir kombucha kimchi chucrute sauerkraut
      ferm iogurte yogurt yoghurt
    ].freeze

    # Legumes, grains and fiber
    LEGUME_KEYWORDS = %w[
      grao grão tortitas
      hummus humus homus
      lentilha lentilhas feijao feijão
      tremoco tremoço tremocos
      fava favas ervilha ervilhas
      falafel aveia aveias
      quinoa quinua
    ].freeze

    # Nuts, seeds and plant omega-3 sources
    NUTS_SEEDS_KEYWORDS = %w[
      chia linhaca linhaça
      nozes noz
      canhamo cânhamo
      amendoa amêndoa amendoim
      caju cajus
      pistach pistacio pistachio pistáchio
      girassol
      sesamo sésamo sesame
      sementes semente
    ].freeze

    # Green leafy vegetables
    GREEN_KEYWORDS = %w[
      espinafre espinafres brocol brócolo broculos bróculos brocolos
      couve couves kale
      rucula rúcula
      agiao agrião
      alface alfaces
    ].freeze

    # General vegetables
    VEGETABLE_KEYWORDS = %w[
      pimento pimentos pimentao pimentão
      cenoura cenouras
      curgete curgetes curgette courgette
      cebola cebolas
      tomate tomates
      pepino pepinos
      beringela beringelas
      cogumelo cogumelos
      aipo abobrinha
      salada saladas
      batata batatas
      legumes vegetais
    ].freeze

    # Fruits
    FRUIT_KEYWORDS = %w[
      banana bananas
      maca maçã macas maçãs
      laranja laranjas
      limao limão limaos limões
      kiwi kiwis
      manga mangas
      pera peras
      uva uvas
      melao melão melancia
      tangerina clementina
      ananas ananás
      papaia mamao mamão
    ].freeze

    # Berries and antioxidant-rich fruits
    BERRY_KEYWORDS = %w[
      mirtilo mirtilos blueberry
      framboesa framboesas raspberry
      amora amoras
      morango morangos strawberry
      berry berries silvestres
      groselha arandos
      acai açaí
    ].freeze

    # Healthy fats
    HEALTHY_FAT_KEYWORDS = %w[
      guacamole
      abacate abacates avocado
      azeite
    ].freeze

    # Sweets and processed (to minimize)
    SWEETS_KEYWORDS = %w[
      chocolate chocolates
      bombom bombons
      bolacha bolachas
      gomas goma
      milka kinder haribo
      croissant donut donuts
      wafer waffles
      cookie cookies
      candy
    ].freeze

    def initialize(days: nil)
      @db = Database.connection
      @days = days
      @date_filter = days ? "AND pu.purchase_date >= date('now', '-#{days} days')" : ""
    end

    def generate
      {
        generated_at: Time.now.iso8601,
        period: period_info,
        summary: summary_stats,
        categories: {
          protein: analyze_category(PROTEIN_KEYWORDS, "Protein Sources"),
          fermented: analyze_category(FERMENTED_KEYWORDS, "Fermented/Probiotic"),
          legumes: analyze_category(LEGUME_KEYWORDS, "Legumes & Fiber"),
          nuts_seeds: analyze_category(NUTS_SEEDS_KEYWORDS, "Nuts, Seeds & Omega-3"),
          greens: analyze_category(GREEN_KEYWORDS, "Green Leafy Vegetables"),
          vegetables: analyze_category(VEGETABLE_KEYWORDS, "Vegetables"),
          fruits: analyze_category(FRUIT_KEYWORDS, "Fruits"),
          berries: analyze_category(BERRY_KEYWORDS, "Berries & Antioxidants"),
          healthy_fats: analyze_category(HEALTHY_FAT_KEYWORDS, "Healthy Fats"),
          sweets: analyze_sweets
        },
        top_products: top_products(25),
        fresh_produce: fresh_produce_analysis,
        health_scores: calculate_health_scores,
        recommendations: generate_recommendations
      }
    end

    private

    def period_info
      result = @db.fetch(<<~SQL).first
        SELECT
          MIN(purchase_date) as start_date,
          MAX(purchase_date) as end_date,
          COUNT(DISTINCT transaction_id) as transactions,
          COUNT(DISTINCT product_id) as unique_products
        FROM purchases pu
        WHERE 1=1 #{@date_filter}
      SQL

      {
        days_analyzed: @days || "all",
        start_date: result[:start_date],
        end_date: result[:end_date],
        transactions: result[:transactions],
        unique_products: result[:unique_products]
      }
    end

    def summary_stats
      result = @db.fetch(<<~SQL).first
        SELECT
          COUNT(DISTINCT pu.transaction_id) as transaction_count,
          ROUND(SUM(t.total), 2) as total_spent,
          COUNT(DISTINCT pu.product_id) as unique_products,
          SUM(pu.quantity) as total_items
        FROM purchases pu
        JOIN transactions t ON pu.transaction_id = t.id
        WHERE 1=1 #{@date_filter}
      SQL

      {
        transactions: result[:transaction_count],
        total_spent_eur: result[:total_spent],
        unique_products: result[:unique_products],
        total_items: result[:total_items].to_f.round(0)
      }
    end

    def analyze_category(keywords, name)
      # Build case-insensitive patterns
      # Note: SQLite LOWER() mangles Portuguese accents (GRÃO -> grÃo)
      # So for accented words, match original + uppercase directly
      patterns = keywords.flat_map do |k|
        if /[áàâãéèêíìîóòôõúùûçÁÀÂÃÉÈÊÍÌÎÓÒÔÕÚÙÛÇ]/.match?(k)
          # For accented: match lowercase, titlecase, and uppercase variants
          [
            "p.name LIKE '%#{k.downcase}%'",
            "p.name LIKE '%#{k.capitalize}%'",
            "p.name LIKE '%#{k.upcase}%'"
          ]
        else
          # For non-accented: LOWER() works fine
          ["LOWER(p.name) LIKE '%#{k.downcase}%'"]
        end
      end
      pattern = patterns.join(" OR ")

      results = @db.fetch(<<~SQL).all
        SELECT
          p.name,
          COUNT(*) as purchase_count,
          SUM(pu.quantity) as total_quantity,
          ROUND(SUM(pu.total), 2) as total_spent
        FROM purchases pu
        JOIN products p ON pu.product_id = p.id
        WHERE (#{pattern}) #{@date_filter}
        GROUP BY p.id
        ORDER BY purchase_count DESC
        LIMIT 15
      SQL

      total_purchases = results.sum { |r| r[:purchase_count] }

      {
        name: name,
        total_purchases: total_purchases,
        total_spent: results.sum { |r| r[:total_spent].to_f }.round(2),
        products: results.map do |r|
          {
            name: r[:name],
            count: r[:purchase_count],
            quantity: r[:total_quantity].to_f.round(1)
          }
        end
      }
    end

    def analyze_sweets
      # Sweets query with exclusions for healthy dark chocolate (85%+) and protein products
      pattern = SWEETS_KEYWORDS.map { |k| "LOWER(p.name) LIKE '%#{k.downcase}%'" }.join(" OR ")
      exclusions = "AND p.name NOT LIKE '%85%' AND p.name NOT LIKE '%90%' " \
                   "AND p.name NOT LIKE '%99%' AND LOWER(p.name) NOT LIKE '%proteic%' " \
                   "AND LOWER(p.name) NOT LIKE '%protein%'"

      results = @db.fetch(<<~SQL).all
        SELECT
          p.name,
          COUNT(*) as purchase_count,
          SUM(pu.quantity) as total_quantity,
          ROUND(SUM(pu.total), 2) as total_spent
        FROM purchases pu
        JOIN products p ON pu.product_id = p.id
        WHERE (#{pattern}) #{exclusions} #{@date_filter}
        GROUP BY p.id
        ORDER BY purchase_count DESC
        LIMIT 15
      SQL

      total_purchases = results.sum { |r| r[:purchase_count] }

      {
        name: "Sweets & Processed",
        total_purchases: total_purchases,
        total_spent: results.sum { |r| r[:total_spent].to_f }.round(2),
        products: results.map do |r|
          {
            name: r[:name],
            count: r[:purchase_count],
            quantity: r[:total_quantity].to_f.round(1)
          }
        end
      }
    end

    def top_products(limit)
      @db.fetch(<<~SQL).all
        SELECT
          p.name,
          COUNT(*) as purchase_count,
          SUM(pu.quantity) as total_quantity
        FROM purchases pu
        JOIN products p ON pu.product_id = p.id
        WHERE 1=1 #{@date_filter}
        GROUP BY p.id
        ORDER BY purchase_count DESC
        LIMIT #{limit}
      SQL
    end

    def fresh_produce_analysis
      vegetables = @db.fetch(<<~SQL).all
        SELECT p.name, COUNT(*) as count
        FROM purchases pu
        JOIN products p ON pu.product_id = p.id
        WHERE LOWER(p.name) LIKE '%kg%'
          AND (
            LOWER(p.name) LIKE '%piment%' OR
            LOWER(p.name) LIKE '%cenour%' OR
            LOWER(p.name) LIKE '%curgete%' OR
            LOWER(p.name) LIKE '%cebola%' OR
            LOWER(p.name) LIKE '%tomate%' OR
            LOWER(p.name) LIKE '%brocol%' OR
            LOWER(p.name) LIKE '%couve%' OR
            LOWER(p.name) LIKE '%beringela%' OR
            LOWER(p.name) LIKE '%pepino%' OR
            LOWER(p.name) LIKE '%alho%' OR
            LOWER(p.name) LIKE '%cogumelo%'
          )
          #{@date_filter}
        GROUP BY p.id
        ORDER BY count DESC
        LIMIT 10
      SQL

      fruits = @db.fetch(<<~SQL).all
        SELECT p.name, COUNT(*) as count
        FROM purchases pu
        JOIN products p ON pu.product_id = p.id
        WHERE LOWER(p.name) LIKE '%kg%'
          AND (
            LOWER(p.name) LIKE '%banana%' OR
            LOWER(p.name) LIKE '%maçã%' OR
            LOWER(p.name) LIKE '%laranja%' OR
            LOWER(p.name) LIKE '%limão%' OR
            LOWER(p.name) LIKE '%kiwi%' OR
            LOWER(p.name) LIKE '%abacate%' OR
            LOWER(p.name) LIKE '%manga%' OR
            LOWER(p.name) LIKE '%mirtilo%'
          )
          #{@date_filter}
        GROUP BY p.id
        ORDER BY count DESC
        LIMIT 10
      SQL

      {
        vegetables: vegetables,
        fruits: fruits,
        vegetable_variety: vegetables.length,
        fruit_variety: fruits.length
      }
    end

    def calculate_health_scores
      categories = {
        protein: analyze_category(PROTEIN_KEYWORDS, "")[:total_purchases],
        fermented: analyze_category(FERMENTED_KEYWORDS, "")[:total_purchases],
        legumes: analyze_category(LEGUME_KEYWORDS, "")[:total_purchases],
        nuts_seeds: analyze_category(NUTS_SEEDS_KEYWORDS, "")[:total_purchases],
        greens: analyze_category(GREEN_KEYWORDS, "")[:total_purchases],
        vegetables: analyze_category(VEGETABLE_KEYWORDS, "")[:total_purchases],
        fruits: analyze_category(FRUIT_KEYWORDS, "")[:total_purchases],
        berries: analyze_category(BERRY_KEYWORDS, "")[:total_purchases],
        healthy_fats: analyze_category(HEALTHY_FAT_KEYWORDS, "")[:total_purchases],
        sweets: analyze_sweets[:total_purchases]
      }

      total = categories.values.sum.to_f
      return {} if total == 0

      {
        protein_score: score_percentage(categories[:protein], total, target: 12),
        fermented_score: score_percentage(categories[:fermented], total, target: 8),
        legume_score: score_percentage(categories[:legumes], total, target: 8),
        nuts_seeds_score: score_percentage(categories[:nuts_seeds], total, target: 5),
        greens_score: score_percentage(categories[:greens], total, target: 5),
        vegetable_score: score_percentage(categories[:vegetables], total, target: 10),
        fruit_score: score_percentage(categories[:fruits], total, target: 8),
        berry_score: score_percentage(categories[:berries], total, target: 3),
        healthy_fat_score: score_percentage(categories[:healthy_fats], total, target: 5),
        sweets_score: 100 - score_percentage(categories[:sweets], total, target: 3),
        overall_health_score: calculate_overall_score(categories, total)
      }
    end

    def score_percentage(value, total, target:)
      actual = (value / total * 100).round(1)
      [(actual / target * 100), 100].min.round(0)
    end

    def calculate_overall_score(categories, total)
      weights = {
        protein: 0.15,
        fermented: 0.10,
        legumes: 0.10,
        nuts_seeds: 0.10,
        greens: 0.10,
        vegetables: 0.15,
        fruits: 0.10,
        berries: 0.05,
        healthy_fats: 0.05,
        sweets: -0.10
      }

      score = 50

      weights.each do |cat, weight|
        pct = (categories[cat] || 0) / total * 100
        score += (pct * weight).round(0)
      end

      score.clamp(0, 100)
    end

    def generate_recommendations
      scores = calculate_health_scores
      recs = []

      if scores[:nuts_seeds_score].to_i < 50
        recs << {
          priority: 1,
          category: "nuts_seeds",
          issue: "Low nuts/seeds intake (omega-3 source)",
          action: "Increase: linhaca, chia, nozes, sementes de canhamo, amendoas. Consider algae EPA/DHA supplement."
        }
      end

      if scores[:greens_score].to_i < 50
        recs << {
          priority: 2,
          category: "greens",
          issue: "Low green leafy vegetable intake",
          action: "Add couve kale, espinafres, rucula, broculos to weekly shopping."
        }
      end

      if scores[:vegetable_score].to_i < 50
        recs << {
          priority: 3,
          category: "vegetables",
          issue: "Low vegetable variety",
          action: "Add more: pimento, cenoura, curgete, tomate, cogumelos."
        }
      end

      if scores[:berry_score].to_i < 50
        recs << {
          priority: 4,
          category: "berries",
          issue: "Low berry/antioxidant intake",
          action: "Add mirtilos, framboesas (frozen ok) 2-3x per week."
        }
      end

      if scores[:sweets_score].to_i < 70
        recs << {
          priority: 5,
          category: "sweets",
          issue: "High processed sweets intake",
          action: "Replace with 85%+ dark chocolate, fruit, or protein bars."
        }
      end

      recs
    end
  end
end
