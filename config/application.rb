require_relative "boot"

require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "active_job/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Tinyslug
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    config.x.app_host = ENV.fetch("APP_HOST", Rails.env.production? ? nil : "localhost:3000")
    config.x.app_protocol = ENV.fetch("APP_PROTOCOL", Rails.env.production? ? "https" : "http")
    config.x.demo_mode_enabled = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DEMO_MODE_ENABLED", false))
    config.x.redirect_visit_retention_days = Integer(ENV.fetch("REDIRECT_VISIT_RETENTION_DAYS", 90), exception: false) || 90
    config.x.custom_domain_dns_target = ENV["CUSTOM_DOMAIN_DNS_TARGET"]
    config.x.custom_domain_txt_prefix = ENV.fetch("CUSTOM_DOMAIN_TXT_PREFIX", "_tinyslug-verification")

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
