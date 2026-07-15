require "test_helper"

class PublicProfilesControllerTest < ActionDispatch::IntegrationTest
  test "disabled and unknown public profiles return not found" do
    get public_profile_path("alice")
    assert_response :not_found

    get public_profile_path("unknown")
    assert_response :not_found
  end

  test "a public page exposes only explicitly selected links and safe profile fields" do
    profiles(:alice).update!(public_enabled: true, bio: "I share small, useful links.")

    get public_profile_path("ALICE")

    assert_response :success
    assert_select "h1", "Alice"
    assert_select "a[href='#{links(:alice_docs).short_url}']", "Product docs"
    assert_select "a[href='#{links(:alice_custom).short_url}']", "Custom link"
    assert_select "a", text: "Bob docs", count: 0
    assert_select "meta[property='og:title'][content='Alice']"
    assert_select "meta[name='description'][content='I share small, useful links.']"
    assert_not_includes response.body, users(:alice).email
  end
end
