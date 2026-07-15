class SocialLink < ApplicationRecord
  MAX_PER_PROFILE = 20

  belongs_to :profile

  validates :label, presence: true, length: { maximum: 40 }
  validates :url, presence: true, length: { maximum: 2048 }, safe_http_url: true
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :profile_link_limit, on: :create

  private

  def profile_link_limit
    return unless profile
    return if profile.social_links.count < MAX_PER_PROFILE

    errors.add(:base, "A profile can have at most #{MAX_PER_PROFILE} social links")
  end
end
