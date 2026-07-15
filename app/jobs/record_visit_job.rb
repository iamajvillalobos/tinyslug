class RecordVisitJob < ApplicationJob
  queue_as :default

  discard_on ActiveRecord::RecordNotFound

  def perform(payload)
    attributes = payload.symbolize_keys
    link = Link.find(attributes.fetch(:link_id))

    return if Visit.exists?(event_key: attributes.fetch(:event_key))

    visit = Visit.create!(event_key: attributes.fetch(:event_key)) do |record|
      record.link = link
      record.visitor_digest = attributes.fetch(:visitor_digest)
      record.browser = attributes[:browser]
      record.device_type = attributes[:device_type]
      record.country_code = attributes[:country_code]
      record.referrer_host = attributes[:referrer_host]
      record.occurred_at = attributes.fetch(:occurred_at)
    end
    Rails.event.notify("tinyslug.visit.recorded", visit_id: visit.id, link_id: link.id)
    visit
  rescue ActiveRecord::RecordNotUnique
    Visit.find_by!(event_key: attributes.fetch(:event_key))
  end
end
