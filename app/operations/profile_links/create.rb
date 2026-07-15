module ProfileLinks
  class Create
    def self.call(profile:, link:)
      record = profile.profile_links.new(link:)
      OrderedProfileItems.append(record:, profile:)
    end
  end
end
