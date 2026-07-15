require "test_helper"

class TaggingTest < ActiveSupport::TestCase
  test "requires link and tag ownership to match" do
    tagging = Tagging.new(link: links(:alice_docs), tag: tags(:bob_docs))

    assert_not tagging.valid?
    assert_includes tagging.errors[:tag], "must belong to the link account"
  end

  test "a tag can be attached only once" do
    duplicate = Tagging.new(link: links(:alice_docs), tag: tags(:alice_docs))

    assert_not duplicate.valid?
  end
end
