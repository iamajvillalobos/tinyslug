require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "registration builds a personal account and profile atomically" do
    user = User.new(
      email: "new@example.com",
      username: " New_User ",
      password: "password123",
      password_confirmation: "password123"
    )

    assert_difference([ "User.count", "Account.count", "Profile.count" ], 1) do
      assert user.save
    end
    assert_equal "new_user", user.username
    assert user.account.personal?
    assert_equal "UTC", user.profile.timezone
  end

  test "invalid associated profile rolls back every registration record" do
    user = User.new(email: "new@example.com", username: "new_user", password: "password123")
    user.build_account(kind: :personal)
    user.build_profile(timezone: "Mars/Olympus")

    assert_no_enqueued_emails do
      assert_no_difference([ "User.count", "Account.count", "Profile.count" ]) do
        assert_not user.save
      end
    end
    assert_includes user.errors.attribute_names, :profile
  end

  test "username is case insensitively unique" do
    duplicate = User.new(email: "other@example.com", username: "ALICE", password: "password123")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:username], "has already been taken"
  end

  test "public shortener account cannot own a user" do
    account = Account.new(kind: :public_shortener, key: "public-shortener")
    user = User.new(account:, email: "internal@example.com", username: "internal", password: "password123")

    assert_not user.valid?
    assert_includes user.errors[:account], "must be personal"
  end
end
