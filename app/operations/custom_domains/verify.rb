require "resolv"
require "timeout"
require "ipaddr"

module CustomDomains
  class Verify
    Result = Data.define(:custom_domain, :errors) do
      def verified? = errors.empty? && custom_domain.verified?
    end

    def self.call(custom_domain:, resolver: nil)
      new(custom_domain:, resolver:).call
    end

    def initialize(custom_domain:, resolver:)
      @custom_domain = custom_domain
      @resolver = resolver
    end

    def call
      errors = []
      dns = resolver || Resolv::DNS.new

      Timeout.timeout(5) do
        errors << "TXT ownership record did not match" unless ownership_verified?(dns)
        errors << "Routing record did not match" unless routing_verified?(dns)
      end

      persist_result(errors)
    rescue Timeout::Error
      persist_result([ "DNS lookup timed out" ])
    rescue Resolv::ResolvError, SocketError
      persist_result([ "DNS lookup failed" ])
    ensure
      dns&.close unless resolver
    end

    private

    attr_reader :custom_domain, :resolver

    def ownership_verified?(dns)
      dns.getresources(custom_domain.txt_record_name, Resolv::DNS::Resource::IN::TXT)
        .any? { |record| record.strings.join == custom_domain.verification_token }
    end

    def routing_verified?(dns)
      target = custom_domain.dns_target.to_s.downcase.delete_suffix(".")
      return false if target.blank?

      address = IPAddr.new(target)
      resource_type = address.ipv4? ? Resolv::DNS::Resource::IN::A : Resolv::DNS::Resource::IN::AAAA
      dns.getresources(custom_domain.hostname, resource_type).any? { |record| record.address.to_s == address.to_s }
    rescue IPAddr::InvalidAddressError
      dns.getresources(custom_domain.hostname, Resolv::DNS::Resource::IN::CNAME)
        .any? { |record| record.name.to_s.downcase.delete_suffix(".") == target }
    end

    def persist_result(errors)
      now = Time.current
      custom_domain.update!(
        status: errors.empty? ? :verified : :failed,
        verified_at: errors.empty? ? (custom_domain.verified_at || now) : nil,
        last_checked_at: now
      )
      Rails.event.notify(
        "tinyslug.custom_domain.checked",
        account_id: custom_domain.account_id,
        custom_domain_id: custom_domain.id,
        status: custom_domain.status,
        error_codes: errors.map { |error| error.parameterize(separator: "_") }
      )
      Result.new(custom_domain, errors.freeze)
    end
  end
end
