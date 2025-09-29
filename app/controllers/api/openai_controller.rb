# frozen_string_literal: true

class Api::OpenaiController < ApplicationController
  skip_before_action :verify_authenticity_token

  def product_feed
    products = Link.alive
      .where.not(user_id: nil)
      .where(draft: false)
      .includes(:user, :thumbnail_alive, :display_asset_previews)

    feed_items = products.filter_map do |product|
      next unless product.published?

      build_product_feed_item(product)
    end

    render json: { products: feed_items }, status: :ok
  end

  private
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
end
