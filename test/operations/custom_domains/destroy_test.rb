require "test_helper"

module CustomDomains
  class DestroyTest < ActiveSupport::TestCase
    test "moves links to primary scope and deterministically renames conflicts" do
      domain = custom_domains(:alice_verified)
      custom_link = links(:alice_custom)
      custom_link.update!(slug: links(:alice_docs).slug)

      result = CustomDomains::Destroy.call(custom_domain: domain, account: accounts(:alice))

      assert_not CustomDomain.exists?(domain.id)
      assert_nil custom_link.reload.custom_domain_id
      assert_equal "docs-link-2", custom_link.slug
      assert_equal "docs-link", result.renamed_links.first.old_slug
      assert_equal "docs-link-2", result.renamed_links.first.new_slug
      assert_equal "docs-link", links(:alice_docs).reload.slug
    end

    test "keeps a non-conflicting slug" do
      domain = custom_domains(:alice_verified)
      custom_link = links(:alice_custom)

      result = CustomDomains::Destroy.call(custom_domain: domain, account: accounts(:alice))

      assert_empty result.renamed_links
      assert_equal "custom-link", custom_link.reload.slug
      assert_nil custom_link.custom_domain_id
    end

    test "rejects a cross-account domain" do
      assert_raises(ActiveRecord::RecordNotFound) do
        CustomDomains::Destroy.call(custom_domain: custom_domains(:bob_verified), account: accounts(:alice))
      end
    end
  end
end
