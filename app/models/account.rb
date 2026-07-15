class Account < ApplicationRecord
  enum :kind, { personal: 0, public_shortener: 1 }, validate: true

  has_one :user, dependent: :destroy, inverse_of: :account
  has_many :links, dependent: :destroy
  has_many :custom_domains, dependent: :destroy
  has_many :tags, dependent: :destroy

  before_validation :generate_key, on: :create
  before_validation :normalize_key

  validates :key, presence: true, uniqueness: true
  validate :public_shortener_has_no_user

  def self.public_shortener
    unless Rails.configuration.x.public_shortener_enabled
      raise ActiveRecord::RecordNotFound, "Public shortener is disabled"
    end

    find_or_create_by!(key: "public-shortener") { |account| account.kind = :public_shortener }
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  private

  def generate_key
    self.key ||= SecureRandom.hex(16)
  end

  def normalize_key
    self.key = key.to_s.strip.downcase
  end

  def public_shortener_has_no_user
    errors.add(:user, "cannot be attached to a public shortener") if public_shortener? && user
  end
end
