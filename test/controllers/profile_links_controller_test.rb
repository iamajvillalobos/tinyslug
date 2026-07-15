require "test_helper"

class ProfileLinksControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "adds, reorders, and removes an account link" do
    link = accounts(:alice).links.create!(name: "Status", destination_url: "https://example.com/status", slug: "status-page", source: :dashboard)

    assert_difference "ProfileLink.count", 1 do
      post profile_links_path, params: { link_id: link.id }
    end
    added = profiles(:alice).profile_links.find_by!(link:)
    assert_redirected_to edit_profile_path(anchor: "public-profile-links")

    patch move_up_profile_link_path(added)
    assert_equal [ 0, 1, 2 ], profiles(:alice).profile_links.reload.pluck(:position)

    assert_difference "ProfileLink.count", -1 do
      delete profile_link_path(added)
    end
    assert_equal [ 0, 1 ], profiles(:alice).profile_links.reload.pluck(:position)
  end

  test "cannot attach a cross-account link" do
    assert_no_difference "ProfileLink.count" do
      post profile_links_path, params: { link_id: links(:bob_docs).id }
    end
    assert_response :not_found
  end

  test "cannot mutate another user's profile link" do
    bob_link = ProfileLinks::Create.call(profile: profiles(:bob), link: links(:bob_docs))

    delete profile_link_path(bob_link)

    assert_response :not_found
    assert ProfileLink.exists?(bob_link.id)
  end
end
