require "test_helper"

module Links
  class CreateTest < ActiveSupport::TestCase
    test "creates a generated slug and normalized tags" do
      result = Links::Create.call(
        account: accounts(:alice),
        attributes: { destination_url: "https://example.com/new", tags: [ " News ", "product" ] },
        source: :dashboard
      )

      assert result.created?
      assert_match(/\A[#{Regexp.escape(Link::SLUG_ALPHABET)}]{8}\z/, result.link.slug)
      assert_equal %w[news product], result.link.tags.order(:name).pluck(:name)
    end

    test "reuses an unnamed link in the same destination and domain scope" do
      result = Links::Create.call(
        account: accounts(:alice),
        attributes: { destination_url: links(:alice_docs).destination_url },
        source: :dashboard
      )

      assert result.reused?
      assert_equal links(:alice_docs), result.link
    end

    test "a requested slug creates a distinct link" do
      result = Links::Create.call(
        account: accounts(:alice),
        attributes: { destination_url: links(:alice_docs).destination_url, slug: "other-docs" },
        source: :dashboard
      )

      assert result.created?
      assert_equal "other-docs", result.link.slug
    end

    test "rejects a custom domain from another account" do
      result = Links::Create.call(
        account: accounts(:alice),
        attributes: {
          destination_url: "https://example.com/new",
          custom_domain_id: custom_domains(:bob_verified).id
        },
        source: :dashboard
      )

      assert_not result.created?
      assert_includes result.link.errors[:custom_domain], "was not found"
    end

    test "retries generated slug collisions" do
      slugs = [ links(:alice_docs).slug, "fresh234" ]

      with_slug_generator(-> { slugs.shift }) do
        result = Links::Create.call(
          account: accounts(:alice),
          attributes: { destination_url: "https://example.com/collision" },
          source: :dashboard
        )

        assert result.created?
        assert_equal "fresh234", result.link.slug
      end
    end

    test "stops after bounded generated slug collisions" do
      colliding_slug = links(:alice_docs).slug

      with_slug_generator(-> { colliding_slug }) do
        result = Links::Create.call(
          account: accounts(:alice),
          attributes: { destination_url: "https://example.com/collision" },
          source: :dashboard
        )

        assert_not result.created?
        assert result.link.errors.of_kind?(:slug, :taken)
      end
    end

    test "public creation ignores member-only options" do
      original = Rails.configuration.x.public_shortener_enabled
      Rails.configuration.x.public_shortener_enabled = true
      account = Account.public_shortener

      result = Links::Create.call(
        account:,
        attributes: {
          destination_url: "https://example.com/public",
          name: "Ignored",
          slug: "requested-slug",
          tracking_enabled: true
        },
        source: :public_shortener
      )

      assert result.created?
      assert result.link.public_shortener?
      assert_not result.link.tracking_enabled?
      assert_nil result.link.custom_domain
      assert_not_equal "requested-slug", result.link.slug
    ensure
      Rails.configuration.x.public_shortener_enabled = original
    end

    private

    def with_slug_generator(generator)
      original = Link.method(:generate_slug)
      Link.define_singleton_method(:generate_slug, generator)
      yield
    ensure
      Link.define_singleton_method(:generate_slug, original)
    end
  end
end
