require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "normalizes whitespace and case" do
    tag = accounts(:alice).tags.create!(name: "  Launch   Notes  ")

    assert_equal "launch notes", tag.name
  end

  test "is unique within an account but reusable across accounts" do
    assert_not accounts(:alice).tags.new(name: "DOCS").valid?
    assert accounts(:bob).tags.new(name: "product").valid?
  end
end
