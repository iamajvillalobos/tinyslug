require "test_helper"

class AnalyticsControllerTest < ActionDispatch::IntegrationTest
  test "renders accessible account analytics" do
    sign_in users(:alice)

    get analytics_path

    assert_response :success
    assert_select "h1", "Analytics"
    assert_select "table", minimum: 2
    assert_select "div[id^=chart-]"
  end

  test "scopes per-link analytics to the current account" do
    sign_in users(:alice)
    get link_analytics_path(links(:alice_docs))
    assert_response :success

    get link_analytics_path(links(:bob_docs))
    assert_response :not_found
  end
end
