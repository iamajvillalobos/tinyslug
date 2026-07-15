class SafeHttpUrlValidator < ActiveModel::EachValidator
  ERROR_MESSAGE = "must be an absolute HTTP or HTTPS URL".freeze

  def validate_each(record, attribute, value)
    return if value.blank? && options[:allow_blank]

    uri = URI::DEFAULT_PARSER.parse(value.to_s.dup)
    valid = %w[http https].include?(uri.scheme&.downcase) &&
      uri.host.present? &&
      uri.userinfo.nil?

    record.errors.add(attribute, options[:message] || ERROR_MESSAGE) unless valid
  rescue URI::InvalidURIError
    record.errors.add(attribute, options[:message] || ERROR_MESSAGE)
  end
end
