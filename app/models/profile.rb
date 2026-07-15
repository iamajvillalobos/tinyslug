class Profile < ApplicationRecord
  TIMEZONE_NAMES = ActiveSupport::TimeZone.all.map(&:name).freeze

  belongs_to :user, inverse_of: :profile

  validates :first_name, :last_name, length: { maximum: 100 }
  validates :timezone, inclusion: { in: TIMEZONE_NAMES }

  def display_name
    [ first_name, last_name ].compact_blank.join(" ").presence || user.username
  end
end
