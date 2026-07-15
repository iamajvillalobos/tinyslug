require "test_helper"

class DemoModeTest < ActionDispatch::IntegrationTest
  BANNER_COPY = "This is a demo instance. All accounts and links are deleted every day."
  REGISTRATION_COPY = "Demo instance: accounts and links here are deleted every day."

  setup do
    @original_setting = Rails.configuration.x.demo_mode_enabled
  end

  teardown do
    Rails.configuration.x.demo_mode_enabled = @original_setting
  end

  test "banner renders for signed-in users when demo mode is on" do
    Rails.configuration.x.demo_mode_enabled = true
    sign_in users(:alice)

    get dashboard_url

    assert_response :success
    assert_includes response.body, BANNER_COPY
    assert_select "a.link[href='https://github.com/iamajvillalobos/tinyslug']", text: "Self-host tinyslug"
  end

  test "banner is absent for logged-out visitors even when demo mode is on" do
    Rails.configuration.x.demo_mode_enabled = true

    get root_url

    assert_response :success
    assert_not_includes response.body, BANNER_COPY
  end

  test "banner is absent when demo mode is off" do
    Rails.configuration.x.demo_mode_enabled = false
    sign_in users(:alice)

    get dashboard_url

    assert_response :success
    assert_not_includes response.body, BANNER_COPY
  end

  test "registration page shows the demo note when demo mode is on" do
    Rails.configuration.x.demo_mode_enabled = true

    get new_user_registration_url

    assert_response :success
    assert_includes response.body, REGISTRATION_COPY
  end

  test "registration page has no demo note when demo mode is off" do
    Rails.configuration.x.demo_mode_enabled = false

    get new_user_registration_url

    assert_response :success
    assert_not_includes response.body, REGISTRATION_COPY
  end
end
