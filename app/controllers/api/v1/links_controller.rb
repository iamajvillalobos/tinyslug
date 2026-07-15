module Api
  module V1
    class LinksController < Api::BaseController
      RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

      rate_limit to: 60,
        within: 1.minute,
        by: -> { Privacy::RateLimitKey.call(current_api_token.account.key) },
        store: RATE_LIMIT_STORE,
        only: :create

      def create
        result = Links::Create.call(
          account: current_api_token.account,
          attributes: link_params,
          source: :api
        )

        if result.created? || result.reused?
          render json: Api::V1::LinkRepresentation.call(result.link), status: result.created? ? :created : :ok
        else
          render json: { errors: result.link.errors.to_hash }, status: :unprocessable_content
        end
      rescue ActionController::ParameterMissing
        render json: { errors: { link: [ "is required" ] } }, status: :unprocessable_content
      end

      private

      def link_params
        params.expect(link: [
          :destination_url,
          :name,
          :slug,
          :custom_domain_id,
          :tracking_enabled,
          { tags: [] }
        ])
      end
    end
  end
end
