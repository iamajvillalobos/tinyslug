class Visit < ApplicationRecord
  belongs_to :link

  validates :event_key, presence: true, uniqueness: true
  validates :visitor_digest, presence: true, format: { with: /\A[a-f0-9]{64}\z/ }
  validates :browser, :device_type, length: { maximum: 100 }, allow_nil: true
  validates :country_code, format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true
  validates :referrer_host, length: { maximum: 253 }, allow_nil: true
  validates :occurred_at, presence: true
end
