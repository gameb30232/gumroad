# frozen_string_literal: true

class Admin::Affiliates::BaseController < Admin::BaseController
  include Admin::FetchAffiliateUser

  protected
    def affiliate_param
      params[:affiliate_id]
    end
end
