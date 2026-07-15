require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "normalizes and generates opaque keys" do
    account = Account.create!(key: "  MIXED-Key ")

    assert_equal "mixed-key", account.key
  end
end
