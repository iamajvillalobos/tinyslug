require "test_helper"

module Visits
  class AnalyticsTest < ActiveSupport::TestCase
    test "aggregates account-scoped metrics in SQL" do
      travel_to Time.utc(2026, 7, 15, 12) do
        create_visit(link: links(:alice_docs), digest: "a" * 64, occurred_at: 1.hour.ago, country: "PH", referrer: nil, browser: "Chrome", device: "desktop")
        create_visit(link: links(:alice_docs), digest: "a" * 64, occurred_at: 30.minutes.ago, country: "PH", referrer: nil, browser: "Chrome", device: "desktop")
        create_visit(link: links(:alice_custom), digest: "b" * 64, occurred_at: 10.minutes.ago, country: "US", referrer: "news.example.com", browser: "Safari", device: "smartphone")
        create_visit(link: links(:bob_docs), digest: "c" * 64, occurred_at: 5.minutes.ago, country: "GB", referrer: nil, browser: "Firefox", device: "desktop")
        create_visit(link: links(:alice_docs), digest: "d" * 64, occurred_at: 31.days.ago)

        result = Visits::Analytics.call(account: accounts(:alice), period: 30, timezone: "UTC")

        assert_equal 3, result.total_visits
        assert_equal 2, result.unique_visits
        assert_equal 3, result.visits_over_time.values.sum
        assert_equal 2, result.top_links.fetch([ links(:alice_docs).id, links(:alice_docs).name ])
        assert_equal 2, result.countries.fetch("PH")
        assert_equal 2, result.referrers.fetch("Direct / None")
        assert_equal 2, result.browsers.fetch("Chrome")
        assert_equal 2, result.devices.fetch("desktop")
      end
    end

    test "groups dates in the profile timezone and filters a requested link" do
      travel_to Time.utc(2026, 7, 15, 12) do
        create_visit(link: links(:alice_docs), digest: "a" * 64, occurred_at: Time.utc(2026, 7, 15, 1))
        create_visit(link: links(:alice_custom), digest: "b" * 64, occurred_at: Time.utc(2026, 7, 15, 2))

        result = Visits::Analytics.call(
          account: accounts(:alice),
          period: 7,
          timezone: "Pacific Time (US & Canada)",
          link: links(:alice_docs)
        )

        assert_equal 1, result.total_visits
        assert_equal [ Date.new(2026, 7, 14) ], result.visits_over_time.keys
      end
    end

    private

    def create_visit(link:, digest:, occurred_at:, country: nil, referrer: nil, browser: nil, device: nil)
      Visit.create!(
        link:,
        event_key: SecureRandom.uuid,
        visitor_digest: digest,
        country_code: country,
        referrer_host: referrer,
        browser:,
        device_type: device,
        occurred_at:
      )
    end
  end
end
