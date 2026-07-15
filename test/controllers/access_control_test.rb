require "test_helper"

class AccessControlTest < ActionDispatch::IntegrationTest
  test "session-only route areas redirect anonymous users to login" do
    protected_paths = [
      dashboard_path,
      edit_profile_path,
      links_path,
      new_link_path,
      analytics_path,
      custom_domains_path,
      new_custom_domain_path,
      api_tokens_path
    ]

    protected_paths.each do |path|
      get path
      assert_redirected_to new_user_session_path, "Expected #{path} to require a session"
    end
  end

  test "documented public route areas remain public" do
    [ root_path, terms_path, privacy_path, api_docs_path, rails_health_check_path, new_user_session_path, new_user_registration_path ].each do |path|
      get path
      assert_response :success, "Expected #{path} to be public"
    end

    get public_profile_path("missing")
    assert_response :not_found

    post api_v1_links_path, params: { link: { destination_url: "https://example.com" } }, as: :json
    assert_response :unauthorized
  end
end
