module Public
  class LinksController < ApplicationController
    RATE_LIMIT_STORE = Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

    rate_limit to: 10,
      within: 1.minute,
      by: -> { Privacy::RateLimitKey.call(request.remote_ip) },
      store: RATE_LIMIT_STORE,
      only: :create

    before_action :ensure_enabled

    def new
      @link = Link.new
    end

    def create
      result = Links::Create.call(
        account: Account.public_shortener,
        attributes: public_link_params,
        source: :public_shortener
      )
      @link = result.link

      respond_to do |format|
        if result.created? || result.reused?
          format.html { render :new, status: result.created? ? :created : :ok }
          format.json { render json: { link: { short_url: @link.short_url } }, status: result.created? ? :created : :ok }
        else
          format.html { render :new, status: :unprocessable_content }
          format.json { render json: { errors: @link.errors.to_hash }, status: :unprocessable_content }
        end
      end
    end

    private

    def ensure_enabled
      head :not_found unless Rails.configuration.x.public_shortener_enabled
    end

    def public_link_params
      params.expect(link: [ :destination_url ])
    end
  end
end
