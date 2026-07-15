class ApiToken < ApplicationRecord
  Result = Data.define(:api_token, :secret)

  belongs_to :account

  scope :active, -> { where(revoked_at: nil) }

  validates :name, presence: true, length: { maximum: 80 }
  validates :token_digest, presence: true, uniqueness: true, format: { with: /\A[a-f0-9]{64}\z/ }
  validates :token_prefix, presence: true, length: { in: 4..20 }

  def self.issue(account:, name:)
    secret = "ts_#{SecureRandom.urlsafe_base64(32, padding: false)}"
    api_token = account.api_tokens.new(
      name:,
      token_digest: digest(secret),
      token_prefix: secret.first(12)
    )
    api_token.save
    Result.new(api_token, api_token.persisted? ? secret : nil)
  end

  def self.authenticate(secret)
    return if secret.blank?

    candidate_digest = digest(secret)
    api_token = active.find_by(token_digest: candidate_digest)
    return unless api_token && ActiveSupport::SecurityUtils.secure_compare(api_token.token_digest, candidate_digest)

    api_token.send(:record_use)
    api_token
  end

  def self.digest(secret)
    OpenSSL::HMAC.hexdigest("SHA256", digest_secret, secret.to_s)
  end

  def self.digest_secret
    ENV.fetch("API_TOKEN_DIGEST_SECRET") do
      Rails.application.secret_key_base || "tinyslug-development-api-token-secret"
    end
  end
  private_class_method :digest_secret

  def revoke!
    update!(revoked_at: Time.current)
  end

  def revoked?
    revoked_at.present?
  end

  def record_use
    now = Time.current
    updated = self.class.where(id:)
      .where("last_used_at IS NULL OR last_used_at < ?", 1.hour.ago)
      .update_all(last_used_at: now)
    self.last_used_at = now if updated.positive?
  end
  private :record_use
end
