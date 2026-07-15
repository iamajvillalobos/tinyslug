require "test_helper"

class RecordVisitJobTest < ActiveJob::TestCase
  test "persists a derived payload idempotently" do
    payload = derived_payload

    assert_event_reported("tinyslug.visit.recorded", payload: { link_id: links(:alice_docs).id }) do
      assert_difference("Visit.count", 1) { RecordVisitJob.perform_now(payload) }
    end
    assert_no_difference("Visit.count") { RecordVisitJob.perform_now(payload.deep_stringify_keys) }

    visit = Visit.find_by!(event_key: payload[:event_key])
    assert_equal "news.example.com", visit.referrer_host
  end

  private

  def derived_payload
    {
      event_key: SecureRandom.uuid,
      link_id: links(:alice_docs).id,
      visitor_digest: "a" * 64,
      browser: "Chrome",
      device_type: "desktop",
      country_code: "PH",
      referrer_host: "news.example.com",
      occurred_at: Time.current
    }
  end
end
