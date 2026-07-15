class CustomDomain < ApplicationRecord
  HOSTNAME_PATTERN = /\A(?=.{1,253}\z)(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/

  enum :status, { pending: 0, verified: 1, failed: 2 }, validate: true

  belongs_to :account
  has_many :links, dependent: :nullify

  before_validation :normalize_hostname
  before_validation :generate_verification_token, on: :create
  before_validation :set_dns_target, on: :create

  validates :hostname,
    presence: true,
    length: { maximum: 253 },
    format: { with: HOSTNAME_PATTERN },
    uniqueness: { case_sensitive: false }
  validates :fallback_url, safe_http_url: { allow_blank: true }, length: { maximum: 2048 }
  validates :verification_token, presence: true, uniqueness: true, length: { minimum: 64 }
  validate :hostname_is_not_reserved
  validate :hostname_is_not_an_ip_address

  def txt_record_name
    "#{Rails.configuration.x.custom_domain_txt_prefix}.#{hostname}"
  end

  private

  def normalize_hostname
    self.hostname = hostname.to_s.strip.downcase.delete_suffix(".")
  end

  def generate_verification_token
    self.verification_token ||= SecureRandom.hex(32)
  end

  def set_dns_target
    self.dns_target ||= Rails.configuration.x.custom_domain_dns_target
  end

  def hostname_is_not_reserved
    primary = Rails.configuration.x.app_host.to_s.split(":").first.downcase
    reserved = [ primary, "www.#{primary}", "api.#{primary}", "assets.#{primary}" ].reject(&:blank?)
    errors.add(:hostname, "is reserved by this application") if hostname.in?(reserved)
  end

  def hostname_is_not_an_ip_address
    IPAddr.new(hostname)
    errors.add(:hostname, "must be a hostname, not an IP address")
  rescue IPAddr::InvalidAddressError
    nil
  end
end
