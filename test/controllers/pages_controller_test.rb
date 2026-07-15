require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "marketing home renders" do
    get root_url

    assert_response :success
    assert_select "h1", /Small links/
    assert_equal "DENY", response.headers["X-Frame-Options"]
    assert_equal "strict-origin-when-cross-origin", response.headers["Referrer-Policy"]
    assert_includes response.headers["Permissions-Policy"], "geolocation=()"
    assert_includes response.headers["Content-Security-Policy"], "default-src 'self'"
  end

  test "terms render" do
    get terms_url

    assert_response :success
    assert_select "h1", "Terms of use"
  end

  test "privacy renders" do
    get privacy_url

    assert_response :success
    assert_select "h1", "Privacy by design"
  end

  test "health endpoint responds" do
    get rails_health_check_url

    assert_response :success
  end

  test "API documentation renders configured examples" do
    get api_docs_url

    assert_response :success
    assert_select "h1", "Create a short link"
    assert_includes response.body, "http://localhost:3000/api/v1/links"
  end
end
