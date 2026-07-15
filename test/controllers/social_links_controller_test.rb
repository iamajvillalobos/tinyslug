require "test_helper"

class SocialLinksControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "adds and removes a social link" do
    assert_difference "SocialLink.count", 1 do
      post social_links_path, params: { social_link: { label: "Website", url: "https://alice.example" } }
    end
    social_link = profiles(:alice).social_links.find_by!(label: "Website")
    assert_redirected_to edit_profile_path(anchor: "social-links")

    assert_difference "SocialLink.count", -1 do
      delete social_link_path(social_link)
    end
  end

  test "renders an accessible error for an unsafe URL" do
    assert_no_difference "SocialLink.count" do
      post social_links_path, params: { social_link: { label: "Bad", url: "javascript:alert(1)" } }
    end

    assert_response :unprocessable_content
    assert_select "[role='alert']", /absolute HTTP or HTTPS URL/
  end
end
