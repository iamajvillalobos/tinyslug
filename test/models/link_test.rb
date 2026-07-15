require "test_helper"

class LinkTest < ActiveSupport::TestCase
  test "normalizes slugs and defaults blank names without changing the destination" do
    destination = +"https://example.com/a/long/path"
    link = Link.new(account: accounts(:alice), destination_url: destination, slug: " New-Link ", source: :dashboard)

    assert link.valid?
    assert_equal "new-link", link.slug
    assert_equal destination, link.name
    assert_equal "https://example.com/a/long/path", destination
  end

  test "rejects reserved and malformed slugs" do
    link = links(:alice_docs)

    %w[api bad_slug -leading two--dashes].each do |slug|
      link.slug = slug
      assert_not link.valid?, slug
    end
  end

  test "requires a selected custom domain to belong to the account" do
    link = links(:alice_docs)
    link.custom_domain = custom_domains(:bob_verified)

    assert_not link.valid?
    assert_includes link.errors[:custom_domain], "must belong to the same account"
  end

  test "primary slug uniqueness is protected by the database" do
    duplicate = accounts(:bob).links.new(
      destination_url: "https://example.org/elsewhere",
      name: "Duplicate",
      slug: links(:alice_docs).slug,
      source: :dashboard
    )

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "the same slug can exist on different custom domains" do
    other_domain = custom_domains(:bob_verified)
    link = other_domain.links.new(
      account: accounts(:bob),
      destination_url: "https://example.org/custom",
      name: "Custom",
      slug: links(:alice_custom).slug,
      source: :dashboard
    )

    assert link.save
  end

  test "public links enforce privacy and ownership invariants" do
    public_account = Account.new(kind: :public_shortener, key: "public-shortener")
    link = Link.new(
      account: public_account,
      destination_url: "https://example.com",
      name: "Public",
      slug: "public-link",
      source: :public_shortener,
      tracking_enabled: true
    )

    assert_not link.valid?
    assert_includes link.errors[:tracking_enabled], "must be disabled for public links"
    assert_includes link.errors[:slug], "must be generated"
  end
end
