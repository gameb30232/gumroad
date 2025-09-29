# frozen_string_literal: true

class Admin::Users::ProductsController < Admin::Users::BaseController
  include Pagy::Backend
  helper Pagy::UrlHelpers

  before_action :fetch_user

  PRODUCTS_ORDER = "ISNULL(COALESCE(purchase_disabled_at, banned_at, links.deleted_at)) DESC, created_at DESC"
  PRODUCTS_PER_PAGE = 10

  def index
    pagy, products = pagy(@user.links.order(Arel.sql(PRODUCTS_ORDER)), limit: PRODUCTS_PER_PAGE)

    render inertia: "Admin/Users/Products/Index", props: inertia_props(
      title:    "#{@user.display_name} on Gumroad",
      user:     @user.as_json_for_admin,
      compliance: {
        reasons: Compliance::TOS_VIOLATION_REASONS,
        default_reason: Compliance::DEFAULT_TOS_VIOLATION_REASON
      },
      products: products.includes(:alive_product_files, :active_integrations).map do |product|
                  product.as_json(
                    admin: true,
                    admins_can_mark_as_staff_picked: ->(product) { policy([:admin, :products, :staff_picked, product]).create? },
                    admins_can_unmark_as_staff_picked: ->(product) { policy([:admin, :products, :staff_picked, product]).destroy? }
                  )
                  end,
      pagy:
    )
  end
end
