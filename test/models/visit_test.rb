require "test_helper"

class VisitTest < ActiveSupport::TestCase
  test "validates privacy-safe normalized fields" do
    visit = Visit.new(
      link: links(:alice_docs),
      event_key: SecureRandom.uuid,
      visitor_digest: "not-a-digest",
      country_code: "usa",
      occurred_at: Time.current
    )

    assert_not visit.valid?
    assert visit.errors[:visitor_digest].any?
    assert visit.errors[:country_code].any?
  end

  test "deleting a link deletes its visits" do
    link = links(:alice_docs)
    visit = create_visit(link:)

    assert_difference("Visit.count", -1) { link.destroy! }
    assert_not Visit.exists?(visit.id)
  end

  private

  def create_visit(link:)
    Visit.create!(
      link:,
      event_key: SecureRandom.uuid,
      visitor_digest: "a" * 64,
      occurred_at: Time.current
    )
  end
end
