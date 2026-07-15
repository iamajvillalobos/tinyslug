class Tagging < ApplicationRecord
  belongs_to :link
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :link_id }
  validate :link_and_tag_share_account

  private

  def link_and_tag_share_account
    return unless link && tag && link.account_id != tag.account_id

    errors.add(:tag, "must belong to the link account")
  end
end
