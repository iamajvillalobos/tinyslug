module Links
  class TagAssignment
    def self.call(link:, account:, names:)
      normalized_names = Array(names).flat_map { |name| name.to_s.split(",") }
        .map { |name| name.strip.gsub(/\s+/, " ").downcase }
        .reject(&:blank?)
        .uniq

      link.tags = normalized_names.map do |name|
        account.tags.find_or_create_by!(name:)
      rescue ActiveRecord::RecordNotUnique
        account.tags.find_by!(name:)
      end
    end
  end
end
