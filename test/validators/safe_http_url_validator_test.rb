require "test_helper"

class SafeHttpUrlValidatorTest < ActiveSupport::TestCase
  test "accepts absolute HTTP and HTTPS URLs" do
    assert build_link("https://example.com/path?q=one").valid?
    assert build_link("http://subdomain.example.com:8080/path").valid?
  end

  test "rejects unsafe and ambiguous destinations" do
    [
      "javascript:alert(1)",
      "/relative/path",
      "https://user:password@example.com/private",
      "https://",
      "https://example .com"
    ].each do |destination|
      link = build_link(destination)

      assert_not link.valid?, destination
      assert_includes link.errors[:destination_url], SafeHttpUrlValidator::ERROR_MESSAGE
    end
  end

  test "does not mutate the caller's string" do
    destination = +"https://Example.com/Path"
    original = destination.dup

    build_link(destination).valid?

    assert_equal original, destination
  end

  private

  def build_link(destination)
    Link.new(
      account: accounts(:alice),
      destination_url: destination,
      name: "Example",
      slug: "example-link",
      source: :dashboard
    )
  end
end
