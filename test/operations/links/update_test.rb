require "test_helper"

module Links
  class UpdateTest < ActiveSupport::TestCase
    test "updates link attributes and tags together" do
      link = links(:alice_docs)

      result = Links::Update.call(
        link:,
        account: accounts(:alice),
        attributes: { name: "Updated", tags: [ "launch" ] }
      )

      assert_equal "Updated", result.name
      assert_equal [ "launch" ], result.tags.pluck(:name)
    end

    test "rejects a cross-account link" do
      assert_raises(ActiveRecord::RecordNotFound) do
        Links::Update.call(link: links(:bob_docs), account: accounts(:alice), attributes: { name: "Nope" })
      end
    end

    test "does not resolve a cross-account custom domain" do
      result = Links::Update.call(
        link: links(:alice_docs),
        account: accounts(:alice),
        attributes: { custom_domain_id: custom_domains(:bob_verified).id }
      )

      assert_includes result.errors[:custom_domain], "was not found"
      assert_nil result.custom_domain
    end
  end
end
