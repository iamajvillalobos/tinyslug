require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows recent links and account stats" do
    sign_in users(:alice)

    get dashboard_path

    assert_response :success
    assert_select "#links-count", text: "2"
    assert_select "#recent-links a[href=?]", links(:alice_docs).short_url, text: links(:alice_docs).short_url
    assert_select "#recent-links a[href=?]", links(:alice_custom).short_url
    assert_select "#recent-links h3", text: "Product docs"
    assert_select "a[href=?]", links_path, text: "Manage links"
    assert_select "p.eyebrow", text: "No links yet", count: 0
  end

  test "limits recent links to the five newest" do
    5.times do |i|
      accounts(:alice).links.create!(destination_url: "https://example.com/recent/#{i}", name: "Recent link #{i}", slug: "recent#{i}xyz", source: :dashboard)
    end

    sign_in users(:alice)
    get dashboard_path

    assert_select "#links-count", text: "7"
    assert_select "#recent-links article", count: 5
    assert_select "#recent-links a[href=?]", links(:alice_docs).short_url, count: 0
  end

  test "counts only this account's visits from the last 7 days" do
    create_visit(link: links(:alice_custom), occurred_at: 1.hour.ago)
    create_visit(link: links(:alice_custom), occurred_at: 2.days.ago)
    create_visit(link: links(:alice_custom), occurred_at: 10.days.ago)
    create_visit(link: links(:bob_docs), occurred_at: 1.hour.ago)

    sign_in users(:alice)
    get dashboard_path

    assert_select "#weekly-visits", text: "2"
  end

  test "shows the empty state when the account has no links" do
    links(:bob_docs).destroy!
    sign_in users(:bob)

    get dashboard_path

    assert_response :success
    assert_select "p.eyebrow", text: "No links yet"
    assert_select "#links-count", text: "0"
    assert_select "#recent-links", count: 0
  end

  test "redirects anonymous visitors to login" do
    get dashboard_path

    assert_redirected_to new_user_session_path
  end

  private

  def create_visit(link:, occurred_at:)
    Visit.create!(
      link:,
      event_key: SecureRandom.uuid,
      visitor_digest: Digest::SHA256.hexdigest(SecureRandom.uuid),
      occurred_at:
    )
  end
end
