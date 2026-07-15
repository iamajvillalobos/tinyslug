require "test_helper"

class SocialLinkTest < ActiveSupport::TestCase
  test "validates label URL and position" do
    social_link = SocialLink.new(profile: profiles(:bob), label: "", url: "javascript:alert(1)", position: -1)

    assert_not social_link.valid?
    assert social_link.errors[:label].any?
    assert social_link.errors[:url].any?
    assert social_link.errors[:position].any?
  end

  test "limits a profile to twenty social links" do
    profile = profiles(:bob)
    20.times do |position|
      profile.social_links.create!(label: "Site #{position}", url: "https://example.com/#{position}", position:)
    end

    extra = profile.social_links.new(label: "One too many", url: "https://example.com/extra", position: 20)
    assert_not extra.valid?
    assert_includes extra.errors[:base], "A profile can have at most 20 social links"
  end
end
