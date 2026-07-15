require "test_helper"

class CustomDomainTest < ActiveSupport::TestCase
  test "normalizes ASCII and punycode hostnames" do
    domain = accounts(:alice).custom_domains.new(hostname: "  XN--BCHER-KVA.Example. ")

    assert domain.valid?
    assert_equal "xn--bcher-kva.example", domain.hostname
    assert_operator domain.verification_token.bytesize, :>=, 64
  end

  test "rejects schemes ports paths whitespace IPs localhost and malformed labels" do
    invalid_hostnames = [
      "https://go.example.com",
      "go.example.com:443",
      "go.example.com/path",
      "go example.com",
      "127.0.0.1",
      "localhost",
      "-bad.example.com",
      "bad-.example.com",
      "single-label"
    ]

    invalid_hostnames.each do |hostname|
      assert_not accounts(:alice).custom_domains.new(hostname:).valid?, hostname
    end
  end

  test "rejects the primary and infrastructure hostnames" do
    original = Rails.configuration.x.app_host
    Rails.configuration.x.app_host = "app.example.test"

    %w[app.example.test www.app.example.test api.app.example.test assets.app.example.test].each do |hostname|
      domain = accounts(:alice).custom_domains.new(hostname:)
      assert_not domain.valid?
      assert_includes domain.errors[:hostname], "is reserved by this application"
    end
  ensure
    Rails.configuration.x.app_host = original
  end

  test "validates fallback URLs without network access" do
    domain = custom_domains(:alice_pending)
    domain.fallback_url = "https://user:secret@example.com/private"

    assert_not domain.valid?
    assert_includes domain.errors[:fallback_url], SafeHttpUrlValidator::ERROR_MESSAGE
  end

  test "case-insensitive uniqueness is protected by the database" do
    duplicate = accounts(:bob).custom_domains.new(
      hostname: custom_domains(:alice_verified).hostname.upcase,
      verification_token: SecureRandom.hex(32),
      status: :pending
    )

    duplicate.hostname = duplicate.hostname.downcase
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
