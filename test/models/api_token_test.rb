require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "issues a secret once and persists only its digest and prefix" do
    result = ApiToken.issue(account: accounts(:alice), name: "Test client")

    assert result.api_token.persisted?
    assert result.secret.start_with?("ts_")
    assert_operator result.secret.delete_prefix("ts_").length, :>=, 43
    assert_equal result.secret.first(12), result.api_token.token_prefix
    assert_equal ApiToken.digest(result.secret), result.api_token.token_digest
    assert_not_includes result.api_token.attributes.values, result.secret
  end

  test "authenticates active tokens and rejects unknown or revoked tokens" do
    result = ApiToken.issue(account: accounts(:alice), name: "Test client")

    assert_equal result.api_token, ApiToken.authenticate(result.secret)
    assert_nil ApiToken.authenticate("ts_unknown")

    result.api_token.revoke!
    assert_nil ApiToken.authenticate(result.secret)
  end

  test "throttles last-used writes to once per hour" do
    result = ApiToken.issue(account: accounts(:alice), name: "Test client")

    freeze_time do
      ApiToken.authenticate(result.secret)
      first_use = result.api_token.reload.last_used_at

      travel 30.minutes
      ApiToken.authenticate(result.secret)
      assert_equal first_use, result.api_token.reload.last_used_at

      travel 31.minutes
      ApiToken.authenticate(result.secret)
      assert_operator result.api_token.reload.last_used_at, :>, first_use
    end
  end

  test "does not issue a secret for an invalid token name" do
    result = ApiToken.issue(account: accounts(:alice), name: "")

    assert_not result.api_token.persisted?
    assert_nil result.secret
  end
end
