require "test_helper"

module Visits
  class PayloadBuilderTest < ActiveSupport::TestCase
    CHROME_USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
    BOT_USER_AGENT = "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

    setup do
      @link = links(:alice_docs)
      @link.update!(tracking_enabled: true)
    end

    test "builds deterministic daily digests and rotates them across UTC days" do
      now = Time.utc(2026, 7, 15, 23, 59)
      first = build(occurred_at: now)
      same_day = build(occurred_at: now + 30.seconds)
      next_day = build(occurred_at: now + 2.minutes)

      assert_equal first[:visitor_digest], same_day[:visitor_digest]
      assert_not_equal first[:visitor_digest], next_day[:visitor_digest]
      assert_match(/\A[a-f0-9]{64}\z/, first[:visitor_digest])
    end

    test "uses an anonymized network prefix and normalized classification" do
      first = build(ip_address: "203.0.113.10")
      same_prefix = build(ip_address: "203.0.113.250")
      other_prefix = build(ip_address: "203.0.114.10")

      assert_equal first[:visitor_digest], same_prefix[:visitor_digest]
      assert_not_equal first[:visitor_digest], other_prefix[:visitor_digest]
    end

    test "retains only safe metadata" do
      payload = build(
        referrer: "https://News.Example.com/article?private=yes#fragment",
        country_code: "ph"
      )

      assert_equal "news.example.com", payload[:referrer_host]
      assert_equal "PH", payload[:country_code]
      assert_equal "Chrome", payload[:browser]
      assert_not_includes payload.to_s, "203.0.113.10"
      assert_not_includes payload.to_s, CHROME_USER_AGENT
      assert_not_includes payload.to_s, "private=yes"
      assert_empty payload.keys.grep(/ip|agent/)
    end

    test "skips disabled opted-out and bot traffic" do
      @link.update!(tracking_enabled: false)
      assert_nil build

      @link.update!(tracking_enabled: true)
      assert_nil build(dnt: "1")
      assert_nil build(gpc: "1")
      assert_nil build(user_agent: BOT_USER_AGENT)
    end

    test "degrades invalid country and referrer metadata to blank" do
      payload = build(referrer: "not a URL", country_code: "unknown")

      assert_nil payload[:referrer_host]
      assert_nil payload[:country_code]
    end

    private

    def build(**overrides)
      Visits::PayloadBuilder.call(**{
        link: @link,
        ip_address: "203.0.113.10",
        user_agent: CHROME_USER_AGENT,
        referrer: nil,
        dnt: nil,
        gpc: nil,
        country_code: nil,
        occurred_at: Time.utc(2026, 7, 15, 12)
      }.merge(overrides))
    end
  end
end
