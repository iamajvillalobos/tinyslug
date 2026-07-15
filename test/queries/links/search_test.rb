require "test_helper"

module Links
  class SearchTest < ActiveSupport::TestCase
    test "searches name destination and slug within the account" do
      _pagy, results = Links::Search.call(account: accounts(:alice), query: "DOCS")

      assert_includes results, links(:alice_docs)
      assert_not_includes results, links(:bob_docs)
    end

    test "filters tags within the account" do
      _pagy, results = Links::Search.call(account: accounts(:alice), tag: "product")

      assert_equal [ links(:alice_docs) ], results.to_a
    end

    test "whitelists sort direction" do
      older = links(:alice_docs)
      newer = links(:alice_custom)
      older.update_column(:created_at, 2.days.ago)
      newer.update_column(:created_at, 1.day.ago)

      _pagy, oldest_first = Links::Search.call(account: accounts(:alice), sort: "oldest")
      _pagy, invalid_sort = Links::Search.call(account: accounts(:alice), sort: "created_at; DROP TABLE links")

      assert_equal older, oldest_first.first
      assert_equal newer, invalid_sort.first
    end

    test "normalizes malformed pages and safely returns empty boundary pages" do
      malformed_pagy, malformed_results = Links::Search.call(account: accounts(:alice), page: "not-a-page")
      boundary_pagy, boundary_results = Links::Search.call(account: accounts(:alice), page: 10_000)

      assert_equal 1, malformed_pagy.page
      assert malformed_results.any?
      assert_equal 10_000, boundary_pagy.page
      assert_empty boundary_results
    end
  end
end
