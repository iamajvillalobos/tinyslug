class Tag < ApplicationRecord
  belongs_to :account
  has_many :taggings, dependent: :destroy
  has_many :links, through: :taggings

  before_validation :normalize_name

  validates :name, presence: true, length: { maximum: 40 }, uniqueness: { scope: :account_id }

  private

  def normalize_name
    self.name = name.to_s.strip.gsub(/\s+/, " ").downcase
  end
end
