# frozen_string_literal: true

require "net/sftp"

class PushOpenaiProductFeedJob
  include Sidekiq::Job
  sidekiq_options retry: 3, queue: :default

  def perform
    # TODO: Get format from Rails credentials once configured (important-comment)
    # format = Rails.application.credentials.dig(:openai_sftp, :format) || 'tsv' (important-comment)
    format = "tsv" # Default to TSV as it's common for data feeds (important-comment)

    begin
      temp_file = generate_feed_file(format)
      upload_to_sftp(temp_file, format)

      SlackMessageWorker.perform_async(
        "integrations",
        "OpenAI Product Feed",
        "Successfully pushed OpenAI product feed (#{format.upcase}) to SFTP",
        "green"
      )
    rescue => e
      SlackMessageWorker.perform_async(
        "integrations",
        "OpenAI Product Feed Error",
        "Failed to push OpenAI product feed: #{e.message}",
        "red"
      )
      raise e
    ensure
      temp_file&.close
      temp_file&.unlink
    end
  end

  private
    def generate_feed_file(format)
      temp_file = Tempfile.new(["openai_product_feed", ".#{format}"])

      products = Link.alive
        .where.not(user_id: nil)
        .where(draft: false)
        .includes(:user, :thumbnail_alive, :display_asset_previews)

      feed_items = products.filter_map do |product|
        next unless product.published?

        build_product_feed_item(product)
      end

      case format
      when "csv"
        temp_file.write(generate_csv(feed_items))
      when "tsv"
        temp_file.write(generate_tsv(feed_items))
      when "xml"
        temp_file.write(generate_xml(feed_items))
      when "json"
        temp_file.write(JSON.pretty_generate({ products: feed_items }))
      end

      temp_file.rewind
      temp_file
    end

    def upload_to_sftp(temp_file, format)
      # TODO: Configure these in Rails credentials (important-comment)
      # Example configuration: (important-comment)
      # openai_sftp: (important-comment)
      #   host: "sftp.example.com" (important-comment)
      #   port: 22 (important-comment)
      #   username: "gumroad_user" (important-comment)
      #   password: "secure_password" (important-comment)
      #   target_directory: "/feeds" (important-comment)
      #   filename_pattern: "gumroad_products_%Y%m%d.tsv" (important-comment)

      credentials = Rails.application.credentials.openai_sftp

      raise "SFTP credentials not configured in Rails credentials" unless credentials

      filename = Time.now.utc.strftime(credentials[:filename_pattern])
      remote_path = File.join(credentials[:target_directory], filename)

      Net::SFTP.start(
        credentials[:host],
        credentials[:username],
        password: credentials[:password],
        port: credentials[:port] || 22,
        auth_methods: %w[password publickey]
      ) do |sftp|
        sftp.upload!(temp_file.path, remote_path)
      end
    end

    def build_product_feed_item(product)
      {
        enable_search: true,
        enable_checkout: true,
        id: product.unique_permalink,
        title: product.name.presence || "Untitled Product",
        description: product.plaintext_description.presence || product.name || "No description available",
        link: product.long_url,
        image_link: product.thumbnail_or_cover_url || default_product_image(product),
        product_category: product_category_for(product),
        brand: "Gumroad",
        material: material_for(product),
        weight: weight_for(product),
        price: format_price(product),
        availability: availability_for(product),
        inventory_quantity: inventory_quantity_for(product),
        seller_name: product.user&.name || "Gumroad Creator",
        seller_url: seller_url_for(product),
        seller_privacy_policy: "https://gumroad.com/privacy",
        seller_tos: "https://gumroad.com/terms",
        return_policy: "https://gumroad.com/refunds",
        return_window: return_window_for(product)
      }
    end

    def product_category_for(product)
      case product.native_type
      when "digital"
        "Media > Digital Products"
      when "physical"
        "Products > Physical Goods"
      when "membership"
        "Services > Memberships"
      when "course"
        "Education > Online Courses"
      when "ebook"
        "Media > Books > Ebooks"
      when "audiobook"
        "Media > Audiobooks"
      when "call"
        "Services > Consultations"
      when "commission"
        "Services > Custom Work"
      when "coffee"
        "Services > Tips & Donations"
      when "bundle"
        "Products > Bundles"
      else
        "Products > Digital Products"
      end
    end

    def material_for(product)
      product.native_type == "physical" ? "Physical" : "Digital"
    end

    def weight_for(product)
      if product.native_type == "physical" && product.require_shipping
        "1 lb"
      else
        "0 lb"
      end
    end

    def format_price(product)
      price_cents = product.price_cents || 0
      price_dollars = (price_cents / 100.0).round(2)
      currency = (product.price_currency_type || "usd").upcase

      "#{price_dollars} #{currency}"
    end

    def availability_for(product)
      if product.is_in_preorder_state
        "preorder"
      else
        "in_stock"
      end
    end

    def inventory_quantity_for(product)
      if product.max_purchase_count.present?
        remaining = product.remaining_for_sale_count
        remaining.present? ? remaining : 0
      else
        999999
      end
    end

    def seller_url_for(product)
      if product.user.present?
        product.user.profile_url
      else
        "https://gumroad.com"
      end
    end

    def return_window_for(product)
      if product.product_refund_policy_enabled?
        30
      else
        0
      end
    end

    def default_product_image(product)
      "https://public-files.gumroad.com/variants/#{product.native_type}/thumbnail.png"
    end

    def generate_csv(feed_items)
      require "csv"
      CSV.generate do |csv|
        csv << csv_headers
        feed_items.each do |item|
          csv << csv_row(item)
        end
      end
    end

    def generate_tsv(feed_items)
      require "csv"
      CSV.generate(col_sep: "\t") do |tsv|
        tsv << csv_headers
        feed_items.each do |item|
          tsv << csv_row(item)
        end
      end
    end

    def generate_xml(feed_items)
      builder = Builder::XmlMarkup.new(indent: 2)
      builder.instruct! :xml, version: "1.0", encoding: "UTF-8"
      builder.products do
        feed_items.each do |item|
          builder.product do
            item.each do |key, value|
              builder.tag!(key, value)
            end
          end
        end
      end
    end

    def csv_headers
      %w[
        id title description link image_link product_category brand material weight
        price availability inventory_quantity seller_name seller_url
        seller_privacy_policy seller_tos return_policy return_window
        enable_search enable_checkout
      ]
    end

    def csv_row(item)
      [
        item[:id],
        item[:title],
        item[:description],
        item[:link],
        item[:image_link],
        item[:product_category],
        item[:brand],
        item[:material],
        item[:weight],
        item[:price],
        item[:availability],
        item[:inventory_quantity],
        item[:seller_name],
        item[:seller_url],
        item[:seller_privacy_policy],
        item[:seller_tos],
        item[:return_policy],
        item[:return_window],
        item[:enable_search],
        item[:enable_checkout]
      ]
    end
end
