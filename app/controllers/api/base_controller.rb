module Api
  class BaseController < ActionController::API
    before_action :authenticate_api_token!

    attr_reader :current_api_token

    private

    def authenticate_api_token!
      scheme, secret = request.authorization.to_s.split(" ", 2)
      @current_api_token = ApiToken.authenticate(secret) if scheme&.casecmp?("Bearer") && secret.present?

      render json: { error: "Unauthorized" }, status: :unauthorized unless current_api_token
    end
  end
end
