module Links
  class Update
    def self.call(link:, account:, attributes:)
      new(link:, account:, attributes:).call
    end

    def initialize(link:, account:, attributes:)
      @link = link
      @account = account
      @attributes = attributes.to_h.deep_symbolize_keys
    end

    def call
      raise ActiveRecord::RecordNotFound unless link.account_id == account.id

      tag_names = attributes.delete(:tags)
      custom_domain = resolve_custom_domain
      return invalid_domain if attributes[:custom_domain_id].present? && !custom_domain

      attributes[:custom_domain] = custom_domain if attributes.key?(:custom_domain_id)
      attributes.delete(:custom_domain_id)

      Link.transaction do
        link.update!(attributes)
        Links::TagAssignment.call(link:, account:, names: tag_names) unless tag_names.nil?
      end
      link
    rescue ActiveRecord::RecordInvalid => error
      link.errors.merge!(error.record.errors) unless error.record.equal?(link)
      link
    end

    private

    attr_reader :link, :account, :attributes

    def resolve_custom_domain
      return unless attributes.key?(:custom_domain_id)
      return if attributes[:custom_domain_id].blank?

      account.custom_domains.find_by(id: attributes[:custom_domain_id])
    end

    def invalid_domain
      link.errors.add(:custom_domain, "was not found")
      link
    end
  end
end
