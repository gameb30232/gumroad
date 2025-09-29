module Admin::FetchProduct
  private

    def fetch_product
      @product = Link.find(product_param)
    end

    def product_param
      params[:product_id]
    end
end
