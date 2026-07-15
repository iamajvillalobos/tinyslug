module Links
  class Create
    MAX_SLUG_ATTEMPTS = 5
    Result = Data.define(:link, :status) do
      def created? = status == :created
      def reused? = status == :reused
    end

    def self.call(account:, attributes:, source:)
      new(account:, attributes:, source:).call
    end

    def initialize(account:, attributes:, source:)
      @account = account
      @attributes = attributes.to_h.deep_symbolize_keys
      @source = source.to_sym
    end

    def call
      tag_names = attributes.delete(:tags)
      requested_name = attributes[:name].present?
      requested_slug = attributes[:slug].present?
      custom_domain_id = attributes.delete(:custom_domain_id)
      custom_domain = resolve_custom_domain(custom_domain_id)
      return finish(Result.new(invalid_link, :invalid)) if custom_domain_id.present? && !custom_domain

      unless requested_name || requested_slug
        existing = duplicate_scope(custom_domain).find_by(destination_url: attributes[:destination_url])
        return finish(Result.new(existing, :reused)) if existing
      end

      finish(create_link(custom_domain:, tag_names:, generated_slug: !requested_slug))
    end

    private

    attr_reader :account, :attributes, :source

    def finish(result)
      Rails.event.notify(
        "tinyslug.link.#{result.status}",
        account_id: account.id,
        link_id: result.link.id,
        source: source,
        custom_domain_id: result.link.custom_domain_id,
        error_fields: result.link.errors.attribute_names
      )
      result
    end

    def resolve_custom_domain(id)
      return if id.blank?

      account.custom_domains.find_by(id:)
    end

    def duplicate_scope(custom_domain)
      account.links.where(custom_domain:)
    end

    def create_link(custom_domain:, tag_names:, generated_slug:)
      link = account.links.new(attributes.merge(custom_domain:, source:))
      attempts = 0

      begin
        attempts += 1
        if generated_slug
          link.slug = Link.generate_slug
          link.slug_generated = true
        end

        Link.transaction do
          link.save!
          Links::TagAssignment.call(link:, account:, names: tag_names)
        end
        Result.new(link, :created)
      rescue ActiveRecord::RecordNotUnique => error
        raise error unless generated_slug && attempts < MAX_SLUG_ATTEMPTS

        link.slug = nil
        retry
      rescue ActiveRecord::RecordInvalid => error
        if error.record.equal?(link) && generated_slug && link.errors.of_kind?(:slug, :taken) && attempts < MAX_SLUG_ATTEMPTS
          link.slug = nil
          link.errors.clear
          retry
        end

        failed_record = error.record
        link.errors.merge!(failed_record.errors) unless failed_record.equal?(link)
        Result.new(link, :invalid)
      end
    end

    def invalid_link
      account.links.new(attributes.except(:custom_domain_id).merge(source:)).tap do |link|
        link.errors.add(:custom_domain, "was not found")
      end
    end
  end
end
