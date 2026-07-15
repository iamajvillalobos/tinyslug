require "application_system_test_case"

class LinkManagementTest < ApplicationSystemTestCase
  test "creates, filters, edits, and deletes a link through Turbo" do
    sign_in_as users(:alice)
    click_link "Links"

    within "#link_form" do
      fill_in "Destination URL", with: "https://example.com/browser-workflow"
      fill_in "Name", with: "Browser workflow"
      fill_in "Slug", with: "browser-workflow"
      fill_in "Tags", with: "system, release"
      check "Privacy-safe analytics"
      click_button "Create short link"
    end

    assert_text "Short link created."
    assert_text "Browser workflow"
    find("input[aria-label='Search links']").set("browser workflow")
    assert_selector "#link_results article", count: 1

    within find("article", text: "Browser workflow") do
      click_link "Edit"
    end
    fill_in "Name", with: "Verified browser workflow"
    click_button "Save link"
    assert_text "Link updated."
    assert_text "Verified browser workflow"

    accept_confirm do
      within find("article", text: "Verified browser workflow") do
        click_button "Delete"
      end
    end
    assert_text "Link deleted."
    assert_no_text "Verified browser workflow"
  end
end
