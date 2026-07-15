require "test_helper"

class ProfileLinkTest < ActiveSupport::TestCase
  test "requires a unique link within a profile" do
    duplicate = ProfileLink.new(profile: profiles(:alice), link: links(:alice_docs), position: 2)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:link_id], "has already been taken"
  end

  test "rejects a link from another account" do
    profile_link = ProfileLink.new(profile: profiles(:alice), link: links(:bob_docs), position: 2)

    assert_not profile_link.valid?
    assert_includes profile_link.errors[:link], "must belong to the profile's account"
  end

  test "requires a non-negative integer position" do
    profile_link = ProfileLink.new(profile: profiles(:bob), link: links(:bob_docs), position: -1)

    assert_not profile_link.valid?
    assert profile_link.errors.of_kind?(:position, :greater_than_or_equal_to)
  end
end
