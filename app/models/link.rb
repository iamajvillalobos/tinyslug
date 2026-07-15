class Link < ApplicationRecord
  SLUG_ALPHABET = "23456789abcdefghjkmnpqrstuvwxyz".freeze
  RESERVED_SLUGS = %w[
    admin analytics api assets cable confirmation dashboard domains login logout
    password privacy profiles rails register settings shorten storage support terms
    tokens up users
  ].freeze
  SLUG_PATTERN = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  enum :source, { dashboard: 0, api: 1, public_shortener: 2 }, validate: true

  belongs_to :account
  belongs_to :custom_domain, optional: true
  has_many :visits, dependent: :destroy
  has_many :taggings, dependent: :destroy
  has_many :tags, through: :taggings

  attr_accessor :slug_generated

  before_validation :normalize_slug
  before_validation :default_name

  validates :destination_url,
    presence: true,
    length: { maximum: 2048 },
    safe_http_url: true
  validates :name, presence: true, length: { maximum: 255 }
  validates :slug,
    presence: true,
    length: { in: 3..64 },
    format: { with: SLUG_PATTERN },
    exclusion: { in: RESERVED_SLUGS },
    uniqueness: { scope: :custom_domain_id }
  validate :custom_domain_belongs_to_account
  validate :public_shortener_invariants

  def self.generate_slug(length: 8)
    Array.new(length) { SLUG_ALPHABET[SecureRandom.random_number(SLUG_ALPHABET.length)] }.join
  end

  def short_url
    host = custom_domain&.hostname || Rails.configuration.x.app_host
    protocol = Rails.configuration.x.app_protocol
    "#{protocol}://#{host}/#{slug}"
  end

  private

  def normalize_slug
    self.slug = slug.to_s.strip.downcase
  end

  def default_name
    self.name = destination_url.to_s.truncate(255, omission: "") if name.blank?
  end

  def custom_domain_belongs_to_account
    return unless custom_domain && custom_domain.account_id != account_id

    errors.add(:custom_domain, "must belong to the same account")
  end

  def public_shortener_invariants
    if public_shortener?
      errors.add(:account, "must be the public shortener") unless account&.public_shortener?
      errors.add(:custom_domain, "is not available for public links") if custom_domain
      errors.add(:tracking_enabled, "must be disabled for public links") if tracking_enabled?
      errors.add(:slug, "must be generated") unless slug_generated
    elsif account&.public_shortener?
      errors.add(:account, "cannot own member links")
    end
  end
end
