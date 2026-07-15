require "ipaddr"

module Visits
  class PayloadBuilder
    def self.call(link:, ip_address:, user_agent:, referrer:, dnt:, gpc:, country_code: nil, occurred_at: Time.current)
      return unless link.tracking_enabled?
      return if link.public_shortener?
      return if dnt.to_s == "1" || gpc.to_s == "1"

      detector = DeviceDetector.new(user_agent.to_s)
      return if detector.bot?

      browser = detector.name.to_s.first(100).presence
      device_type = detector.device_type.to_s.first(100).presence
      normalized_country = normalize_country(country_code)

      {
        event_key: SecureRandom.uuid,
        link_id: link.id,
        visitor_digest: visitor_digest(
          link:,
          ip_address:,
          occurred_at:,
          classification: [ browser, device_type ].compact.join("|")
        ),
        browser:,
        device_type:,
        country_code: normalized_country,
        referrer_host: normalize_referrer(referrer),
        occurred_at:
      }
    end

    def self.visitor_digest(link:, ip_address:, occurred_at:, classification:)
      material = [
        link.id,
        occurred_at.utc.to_date.iso8601,
        anonymized_network(ip_address),
        classification.presence || "unknown"
      ].join("|")
      OpenSSL::HMAC.hexdigest("SHA256", digest_secret, material)
    end
    private_class_method :visitor_digest

    def self.anonymized_network(ip_address)
      address = IPAddr.new(ip_address.to_s)
      address.mask(address.ipv4? ? 24 : 48).to_s
    rescue IPAddr::InvalidAddressError
      "unknown"
    end
    private_class_method :anonymized_network

    def self.normalize_referrer(referrer)
      host = URI::DEFAULT_PARSER.parse(referrer.to_s).host
      host.to_s.downcase.delete_suffix(".").first(253).presence
    rescue URI::InvalidURIError
      nil
    end
    private_class_method :normalize_referrer

    def self.normalize_country(country_code)
      normalized = country_code.to_s.strip.upcase
      normalized.match?(/\A[A-Z]{2}\z/) ? normalized : nil
    end
    private_class_method :normalize_country

    def self.digest_secret
      ENV.fetch("VISITOR_DIGEST_SECRET") do
        Rails.application.secret_key_base || "tinyslug-development-visitor-secret"
      end
    end
    private_class_method :digest_secret
  end
end
