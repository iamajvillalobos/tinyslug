require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "requires a recognized timezone" do
    profile = profiles(:alice)
    profile.timezone = "Mars/Olympus"

    assert_not profile.valid?
  end

  test "uses the username when a name is blank" do
    assert_equal "alice", profiles(:alice).tap { |profile| profile.first_name = nil }.display_name
  end

  test "rejects unsupported avatar content types" do
    profile = profiles(:alice)
    profile.avatar.attach(
      io: file_fixture("not_an_image.txt").open,
      filename: "not_an_image.txt",
      content_type: "text/plain"
    )

    assert_not profile.valid?
    assert profile.errors[:avatar].any?
  end
end
