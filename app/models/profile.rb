class Profile < ApplicationRecord
  TIMEZONE_NAMES = ActiveSupport::TimeZone.all.map(&:name).freeze

  belongs_to :user, inverse_of: :profile
  has_one_attached :avatar
  has_many :profile_links, -> { order(:position) }, dependent: :destroy
  has_many :social_links, -> { order(:position) }, dependent: :destroy

  validates :first_name, :last_name, length: { maximum: 100 }
  validates :bio, length: { maximum: 500 }
  validates :timezone, inclusion: { in: TIMEZONE_NAMES }
  validates :avatar,
    content_type: %w[image/png image/jpeg image/webp],
    size: { less_than_or_equal_to: 5.megabytes }

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || user.username
  end
end
