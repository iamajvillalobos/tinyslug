require "test_helper"

class OrderedProfileItemsTest < ActiveSupport::TestCase
  test "append, move, and destroy keep positions contiguous" do
    profile = profiles(:alice)
    added_link = profile.user.account.links.create!(
      name: "Status",
      destination_url: "https://example.com/status",
      slug: "status-link",
      source: :dashboard
    )

    added = ProfileLinks::Create.call(profile:, link: added_link)
    assert_equal [ 0, 1, 2 ], profile.profile_links.reload.pluck(:position)

    OrderedProfileItems.move(record: added, profile:, direction: :up)
    assert_equal [ links(:alice_docs).id, added_link.id, links(:alice_custom).id ], profile.profile_links.reload.pluck(:link_id)
    assert_equal [ 0, 1, 2 ], profile.profile_links.pluck(:position)

    OrderedProfileItems.destroy(record: profile_links(:alice_docs), profile:)
    assert_equal [ 0, 1 ], profile.profile_links.reload.pluck(:position)
  end

  test "moving beyond either boundary is a contiguous no-op" do
    profile = profiles(:alice)

    OrderedProfileItems.move(record: profile.profile_links.first, profile:, direction: :up)
    OrderedProfileItems.move(record: profile.profile_links.last, profile:, direction: :down)

    assert_equal [ 0, 1 ], profile.profile_links.reload.pluck(:position)
  end
end
