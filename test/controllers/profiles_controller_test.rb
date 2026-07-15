require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get edit_profile_path

    assert_redirected_to new_user_session_path
  end

  test "updates only the signed-in user's profile" do
    sign_in users(:alice)

    patch profile_path, params: { profile: { first_name: "Alicia", timezone: "UTC" } }

    assert_redirected_to edit_profile_path
    assert_equal "Alicia", profiles(:alice).reload.first_name
    assert_equal "Bob", profiles(:bob).reload.first_name
  end

  test "renders validation errors" do
    sign_in users(:alice)

    patch profile_path, params: { profile: { timezone: "Mars/Olympus" } }

    assert_response :unprocessable_content
    assert_select "[role=alert]"
  end
end
