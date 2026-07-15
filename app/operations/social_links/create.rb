module SocialLinks
  class Create
    def self.call(profile:, attributes:)
      record = profile.social_links.new(attributes)
      OrderedProfileItems.append(record:, profile:)
    end
  end
end
