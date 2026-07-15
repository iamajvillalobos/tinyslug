module Links
  class Resolve
    Outcome = Data.define(:status, :link, :fallback_url) do
      def found? = status == :found
      def fallback? = status == :fallback
      def not_found? = status == :not_found
    end

    def self.call(host:, slug:, primary_host:)
      normalized_host = normalize_host(host)
      normalized_primary_host = normalize_host(primary_host)
      normalized_slug = slug.to_s.strip.downcase

      if normalized_host == normalized_primary_host
        link = Link.find_by(custom_domain_id: nil, slug: normalized_slug)
        return Outcome.new(link ? :found : :not_found, link, nil)
      end

      domain = CustomDomain.verified.find_by(hostname: normalized_host)
      return Outcome.new(:not_found, nil, nil) unless domain

      link = domain.links.find_by(slug: normalized_slug)
      return Outcome.new(:found, link, nil) if link
      return Outcome.new(:fallback, nil, domain.fallback_url) if domain.fallback_url.present?

      Outcome.new(:not_found, nil, nil)
    end

    def self.normalize_host(host)
      host.to_s.strip.downcase.delete_suffix(".").sub(/:\d+\z/, "")
    end
    private_class_method :normalize_host
  end
end
