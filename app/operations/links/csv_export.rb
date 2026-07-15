module Links
  class CsvExport
    HEADERS = %w[name destination_url slug short_url custom_domain tracking_enabled tags created_at].freeze
    FORMULA_PREFIX = /\A[=+\-@]/

    def self.call(links)
      rows = links.map do |link|
        [
          safe(link.name),
          safe(link.destination_url),
          safe(link.slug),
          safe(link.short_url),
          safe(link.custom_domain&.hostname),
          link.tracking_enabled?,
          safe(link.tags.map(&:name).join(", ")),
          link.created_at.iso8601
        ]
      end

      ([ HEADERS ] + rows).map { |row| row.map { |value| quote(value) }.join(",") }.join("\r\n") + "\r\n"
    end

    def self.safe(value)
      string = value.to_s
      string.match?(FORMULA_PREFIX) ? "'#{string}" : string
    end

    def self.quote(value)
      %Q("#{value.to_s.gsub('"', '""')}")
    end
    private_class_method :safe, :quote
  end
end
