require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "registration persists an unconfirmed account and enqueues confirmation" do
    assert_enqueued_emails 1 do
      assert_difference([ "User.count", "Account.count", "Profile.count" ], 1) do
        post user_registration_path, params: {
          user: {
            username: "new_user",
            email: "new@example.com",
            password: "password123",
            password_confirmation: "password123"
          }
        }
      end
    end

    assert_redirected_to root_path
    assert_not User.find_by!(email: "new@example.com").confirmed?
  end

  test "a confirmation token activates login and dashboard access" do
    user = User.create!(email: "new@example.com", username: "new_user", password: "password123")
    raw_token, encrypted_token = Devise.token_generator.generate(User, :confirmation_token)
    user.update_columns(confirmation_token: encrypted_token, confirmation_sent_at: Time.current)

    get user_confirmation_path, params: { confirmation_token: raw_token }

    assert user.reload.confirmed?
    assert_redirected_to new_user_session_path

    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    assert_redirected_to dashboard_path
  end

  test "login can be remembered and logout clears the session" do
    post user_session_path, params: {
      user: { email: users(:alice).email, password: "password123", remember_me: "1" }
    }

    assert_redirected_to dashboard_path
    assert cookies["remember_user_token"].present?

    delete destroy_user_session_path
    assert_redirected_to root_path

    get dashboard_path
    assert_redirected_to new_user_session_path
  end

  test "password recovery enqueues instructions" do
    assert_enqueued_emails 1 do
      post user_password_path, params: { user: { email: users(:alice).email } }
    end

    assert_redirected_to new_user_session_path
  end

  test "deleting an account removes the user and profile" do
    sign_in users(:alice)

    assert_difference([ "Account.count", "User.count", "Profile.count" ], -1) do
      delete user_registration_path
    end

    assert_redirected_to root_path
  end
end
