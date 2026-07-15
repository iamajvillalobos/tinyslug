require "test_helper"

class VisitRetentionJobTest < ActiveJob::TestCase
  test "deletes only visits beyond retention" do
    expired = create_visit(occurred_at: 91.days.ago)
    retained = create_visit(occurred_at: 89.days.ago)

    VisitRetentionJob.perform_now(retention_days: 90)

    assert_not Visit.exists?(expired.id)
    assert Visit.exists?(retained.id)
  end

  private

  def create_visit(occurred_at:)
    Visit.create!(
      link: links(:alice_docs),
      event_key: SecureRandom.uuid,
      visitor_digest: SecureRandom.hex(32),
      occurred_at:
    )
  end
end
