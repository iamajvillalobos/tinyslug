require "test_helper"

class RedirectsControllerTest < ActionDispatch::IntegrationTest
  test "redirects a primary-domain slug without fetching its destination" do
    links(:alice_docs).update!(destination_url: "http://127.0.0.1:1/service-is-not-running")
    host! "localhost"

    get short_link_path(links(:alice_docs).slug)

    assert_response :found
    assert_redirected_to links(:alice_docs).destination_url
  end

  test "returns not found for an unknown primary slug" do
    host! "localhost"

    get short_link_path("missing-link")

    assert_response :not_found
  end

  test "verified custom hosts resolve only their own links" do
    host! custom_domains(:alice_verified).hostname

    get short_link_path(links(:alice_custom).slug)
    assert_redirected_to links(:alice_custom).destination_url

    get short_link_path(links(:alice_docs).slug)
    assert_response :not_found
  end

  test "unverified and unknown custom hosts never resolve" do
    host! custom_domains(:alice_pending).hostname
    get short_link_path(links(:alice_custom).slug)
    assert_response :not_found

    host! "unknown.example.test"
    get short_link_path(links(:alice_custom).slug)
    assert_response :not_found
  end

  test "specific application routes take precedence over slugs" do
    host! "localhost"
    get rails_health_check_path
    assert_response :success

    get new_user_session_path
    assert_response :success
  end
end
