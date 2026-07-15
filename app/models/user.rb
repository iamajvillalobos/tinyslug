class User < ApplicationRecord
  devise :confirmable, :database_authenticatable, :recoverable, :registerable,
    :rememberable, :validatable

  belongs_to :account, inverse_of: :user, autosave: true
  has_one :profile, dependent: :destroy, inverse_of: :user, autosave: true

  before_validation :build_personal_records, on: :create
  before_validation :normalize_username

  validates :username,
    presence: true,
    length: { in: 3..30 },
    format: { with: /\A[a-z0-9_]+\z/ },
    uniqueness: { case_sensitive: false }
  validates_associated :account, :profile
  validate :account_must_be_personal

  private

  def send_devise_notification(notification, *args)
    ActiveRecord.after_all_transactions_commit do
      devise_mailer.send(notification, self, *args).deliver_later
    end
  end

  def build_personal_records
    build_account(kind: :personal) unless account
    build_profile unless profile
  end

  def normalize_username
    self.username = username.to_s.strip.downcase
  end

  def account_must_be_personal
    errors.add(:account, "must be personal") if account && !account.personal?
  end
end
