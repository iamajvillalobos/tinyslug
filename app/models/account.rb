class Account < ApplicationRecord
  has_one :user, dependent: :destroy, inverse_of: :account
  has_many :links, dependent: :destroy
  has_many :custom_domains, dependent: :destroy
  has_many :tags, dependent: :destroy
  has_many :api_tokens, dependent: :destroy

  before_validation :generate_key, on: :create
  before_validation :normalize_key

  validates :key, presence: true, uniqueness: true

  private

  def generate_key
    self.key ||= SecureRandom.hex(16)
  end

  def normalize_key
    self.key = key.to_s.strip.downcase
  end
end
