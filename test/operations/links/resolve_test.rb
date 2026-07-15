require "test_helper"

module Links
  class ResolveTest < ActiveSupport::TestCase
    test "resolves primary links with normalized host and slug" do
      outcome = Links::Resolve.call(host: "LOCALHOST:3000", slug: "DOCS-LINK", primary_host: "localhost:3000")

      assert outcome.found?
      assert_equal links(:alice_docs), outcome.link
    end

    test "resolves links only on verified custom domains" do
      found = Links::Resolve.call(host: "go.alice.test", slug: "custom-link", primary_host: "localhost:3000")
      missing = Links::Resolve.call(host: "pending.alice.test", slug: "custom-link", primary_host: "localhost:3000")

      assert found.found?
      assert missing.not_found?
    end

    test "returns a configured custom-domain fallback" do
      domain = custom_domains(:alice_verified)
      domain.update!(fallback_url: "https://example.com/fallback")

      outcome = Links::Resolve.call(host: domain.hostname, slug: "missing-link", primary_host: "localhost:3000")

      assert outcome.fallback?
      assert_equal domain.fallback_url, outcome.fallback_url
    end
  end
end
