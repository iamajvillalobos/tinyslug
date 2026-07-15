require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:alice)
  end

  test "shows a newly created secret exactly once" do
    assert_difference("accounts(:alice).api_tokens.count", 1) do
      post api_tokens_path, params: { api_token: { name: "CLI" } }
    end

    assert_response :created
    secret = response.body.match(/ts_[A-Za-z0-9_-]{43}/)&.to_s
    assert secret.present?
    assert_not_includes ApiToken.last.attributes.values, secret

    get api_tokens_path
    assert_response :success
    assert_not_includes response.body, secret
    assert_includes response.body, ApiToken.last.token_prefix
  end

  test "renders invalid names without creating a token" do
    assert_no_difference("ApiToken.count") do
      post api_tokens_path, params: { api_token: { name: "" } }
    end

    assert_response :unprocessable_content
  end

  test "revokes only a token owned by the current account" do
    own = ApiToken.issue(account: accounts(:alice), name: "Own").api_token
    other = ApiToken.issue(account: accounts(:bob), name: "Other").api_token

    delete revoke_api_token_path(own)
    assert_redirected_to api_tokens_path
    assert own.reload.revoked?

    sign_in users(:alice)
    delete revoke_api_token_path(other)
    assert_response :not_found
    assert_not other.reload.revoked?
  end
end
