module Privacy
  class RateLimitKey
    def self.call(value)
      OpenSSL::HMAC.hexdigest("SHA256", secret, value.to_s)
    end

    def self.secret
      ENV.fetch("RATE_LIMIT_DIGEST_SECRET") do
        Rails.application.secret_key_base || "tinyslug-development-rate-limit-secret"
      end
    end

    private_class_method :secret
  end
end
