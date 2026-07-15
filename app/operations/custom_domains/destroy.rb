module CustomDomains
  class Destroy
    Rename = Data.define(:link, :old_slug, :new_slug)
    Result = Data.define(:custom_domain, :renamed_links)

    def self.call(custom_domain:, account:)
      new(custom_domain:, account:).call
    end

    def initialize(custom_domain:, account:)
      @custom_domain = custom_domain
      @account = account
    end

    def call
      raise ActiveRecord::RecordNotFound unless custom_domain.account_id == account.id

      renamed_links = []
      CustomDomain.transaction do
        custom_domain.lock!
        reserved_slugs = account.links.where(custom_domain_id: nil).pluck(:slug).index_with(true)

        custom_domain.links.lock.order(:id).each do |link|
          old_slug = link.slug
          new_slug = reserved_slugs.key?(old_slug) ? allocate_slug(old_slug, reserved_slugs) : old_slug
          link.update!(custom_domain: nil, slug: new_slug)
          reserved_slugs[new_slug] = true
          renamed_links << Rename.new(link, old_slug, new_slug) if new_slug != old_slug
        end

        custom_domain.destroy!
      end

      Result.new(custom_domain, renamed_links.freeze)
    end

    private

    attr_reader :custom_domain, :account

    def allocate_slug(original, reserved_slugs)
      counter = 2
      loop do
        suffix = "-#{counter}"
        candidate = "#{original.first(64 - suffix.length)}#{suffix}"
        return candidate unless reserved_slugs.key?(candidate)

        counter += 1
      end
    end
  end
end
