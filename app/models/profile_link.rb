class ProfileLink < ApplicationRecord
  belongs_to :profile
  belongs_to :link

  validates :link_id, uniqueness: { scope: :profile_id }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :link_belongs_to_profile_account

  private

  def link_belongs_to_profile_account
    return unless profile && link
    return if profile.user.account_id == link.account_id

    errors.add(:link, "must belong to the profile's account")
  end
end
