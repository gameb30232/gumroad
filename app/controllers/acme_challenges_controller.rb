# frozen_string_literal: true

class AcmeChallengesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!

  def show
    challenge_token = params[:token]
    redis_key = "acme_challenge:#{challenge_token}"

    challenge_content = $redis.get(redis_key)

    if challenge_content
      render plain: challenge_content, content_type: "text/plain"
    else
      head :not_found
    end
  end
end
