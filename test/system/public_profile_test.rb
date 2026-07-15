require "application_system_test_case"

class PublicProfileTest < ApplicationSystemTestCase
  test "enables and edits a public profile with keyboard-operable ordering" do
    sign_in_as users(:alice)
    visit edit_profile_path

    check "Enable public profile"
    click_button "Save profile"
    assert_text "Profile settings saved."

    within "#public-profile-links" do
      move_down = all(:button, "Move down").first
      move_down.send_keys(:enter)
    end
    assert_text "Public links reordered."

    within "#social-links" do
      fill_in "Label", with: "Unsafe"
      fill_in "Url", with: "javascript:alert(1)"
      click_button "Add social link"
    end
    assert_selector "[role='alert']", text: "absolute HTTP or HTTPS URL"

    within "#social-links" do
      fill_in "Label", with: "Website"
      fill_in "Url", with: "https://alice.example"
      click_button "Add social link"
    end
    assert_text "Social link added."

    click_link "View public profile"
    assert_current_path public_profile_path("alice")
    assert_text "Alice"
    assert_link "Product docs"
    assert_link "Custom link"
    assert_link "Website", href: "https://alice.example"
    assert_no_text users(:alice).email
  end
end

class PublicProfileWithoutJavaScriptTest < ActionDispatch::SystemTestCase
  driven_by :rack_test

  test "public profile editing and rendering work without JavaScript" do
    visit new_user_session_path
    fill_in "Email", with: users(:alice).email
    fill_in "Password", with: "password123"
    click_button "Log in"

    visit edit_profile_path
    check "Enable public profile"
    click_button "Save profile"
    assert_text "Profile settings saved."

    within "#social-links" do
      fill_in "Label", with: "Website"
      fill_in "Url", with: "https://alice.example"
      click_button "Add social link"
    end
    assert_text "Social link added."

    visit public_profile_path("alice")
    assert_text "Alice"
    assert_link "Product docs"
    assert_link "Website", href: "https://alice.example"
  end
end
