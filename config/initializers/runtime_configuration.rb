unless ENV["SECRET_KEY_BASE_DUMMY"]
  required_production_settings = %w[
    APP_HOST
    DATABASE_URL
    API_TOKEN_DIGEST_SECRET
    RATE_LIMIT_DIGEST_SECRET
    VISITOR_DIGEST_SECRET
  ]
  missing_settings = required_production_settings.select { |name| ENV[name].blank? }

  if Rails.env.production? && missing_settings.any?
    raise "Missing required production settings: #{missing_settings.join(', ')}"
  end
end

Rails.application.routes.default_url_options = {
  host: Rails.configuration.x.app_host,
  protocol: Rails.configuration.x.app_protocol
}
