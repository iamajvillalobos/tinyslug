require "test_helper"

module CustomDomains
  class VerifyTest < ActiveSupport::TestCase
    FakeResolver = Struct.new(:records) do
      def getresources(name, type)
        value = records.fetch([ name.to_s, type ], [])
        raise value if value.is_a?(Exception)

        value
      end
    end

    TxtRecord = Struct.new(:strings)
    CnameRecord = Struct.new(:name)

    test "verifies matching ownership and routing records idempotently" do
      domain = custom_domains(:alice_pending)
      resolver = resolver_for(domain)

      travel_to Time.utc(2026, 7, 15, 12) do
        first = CustomDomains::Verify.call(custom_domain: domain, resolver:)
        verified_at = domain.reload.verified_at

        travel 1.hour
        second = CustomDomains::Verify.call(custom_domain: domain, resolver:)

        assert first.verified?
        assert second.verified?
        assert_equal verified_at, domain.reload.verified_at
        assert_equal Time.current, domain.last_checked_at
      end
    end

    test "fails closed when ownership or routing does not match" do
      domain = custom_domains(:alice_verified)
      resolver = FakeResolver.new({})

      result = CustomDomains::Verify.call(custom_domain: domain, resolver:)

      assert_not result.verified?
      assert domain.reload.failed?
      assert_nil domain.verified_at
      assert_equal [ "TXT ownership record did not match", "Routing record did not match" ], result.errors
      assert_not_includes result.errors.to_s, domain.verification_token
    end

    test "returns a structured timeout without raising" do
      domain = custom_domains(:alice_pending)
      resolver = FakeResolver.new({
        [ domain.txt_record_name, Resolv::DNS::Resource::IN::TXT ] => Timeout::Error.new
      })

      result = CustomDomains::Verify.call(custom_domain: domain, resolver:)

      assert_equal [ "DNS lookup timed out" ], result.errors
      assert domain.reload.failed?
      assert domain.last_checked_at
    end

    private

    def resolver_for(domain)
      FakeResolver.new({
        [ domain.txt_record_name, Resolv::DNS::Resource::IN::TXT ] => [ TxtRecord.new([ domain.verification_token ]) ],
        [ domain.hostname, Resolv::DNS::Resource::IN::CNAME ] => [ CnameRecord.new(domain.dns_target) ]
      })
    end
  end
end
