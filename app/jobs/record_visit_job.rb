class RecordVisitJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(payload)
    attributes = payload.symbolize_keys
    link = Link.find(attributes.fetch(:link_id))

    return if Visit.exists?(event_key: attributes.fetch(:event_key))

    Visit.create!(event_key: attributes.fetch(:event_key)) do |visit|
      visit.link = link
      visit.visitor_digest = attributes.fetch(:visitor_digest)
      visit.browser = attributes[:browser]
      visit.device_type = attributes[:device_type]
      visit.country_code = attributes[:country_code]
      visit.referrer_host = attributes[:referrer_host]
      visit.occurred_at = attributes.fetch(:occurred_at)
    end
  rescue ActiveRecord::RecordNotUnique
    Visit.find_by!(event_key: attributes.fetch(:event_key))
  end
end
