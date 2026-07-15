require "test_helper"

class AccountTest < ActiveSupport::TestCase
  test "normalizes and generates opaque keys" do
    account = Account.create!(kind: :personal, key: "  MIXED-Key ")

    assert_equal "mixed-key", account.key
  end

  test "public shortener is unavailable by default" do
    assert_raises(ActiveRecord::RecordNotFound) { Account.public_shortener }
  end
end
