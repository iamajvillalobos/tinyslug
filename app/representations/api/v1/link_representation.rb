module Api
  module V1
    class LinkRepresentation
      def self.call(link)
        {
          link: {
            id: link.id,
            name: link.name,
            destination_url: link.destination_url,
            slug: link.slug,
            short_url: link.short_url,
            tracking_enabled: link.tracking_enabled?,
            tags: link.tags.order(:name).pluck(:name),
            created_at: link.created_at.iso8601
          }
        }
      end
    end
  end
end
