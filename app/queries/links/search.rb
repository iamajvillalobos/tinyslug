module Links
  class Search
    DEFAULT_LIMIT = 20
    SORTS = {
      "newest" => { created_at: :desc },
      "oldest" => { created_at: :asc }
    }.freeze

    def self.call(account:, query: nil, tag: nil, sort: nil, page: nil, limit: DEFAULT_LIMIT)
      new(account:, query:, tag:, sort:, page:, limit:).call
    end

    def initialize(account:, query:, tag:, sort:, page:, limit:)
      @account = account
      @query = query.to_s.strip
      @tag = tag.to_s.strip
      @sort = SORTS.fetch(sort.to_s, SORTS.fetch("newest"))
      @page = normalize_positive_integer(page, fallback: 1)
      @limit = normalize_positive_integer(limit, fallback: DEFAULT_LIMIT).clamp(1, 100)
    end

    def call
      relation = account.links.includes(:custom_domain, :tags)
      relation = apply_query(relation)
      relation = apply_tag(relation)
      relation = relation.order(sort)

      pagy = Pagy::Offset.new(count: relation.count(:all), page:, limit:)
      [ pagy, pagy.records(relation) ]
    end

    private

    attr_reader :account, :query, :tag, :sort, :page, :limit

    def apply_query(relation)
      return relation if query.blank?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
      relation.where("links.name ILIKE :pattern OR links.destination_url ILIKE :pattern OR links.slug ILIKE :pattern", pattern:)
    end

    def apply_tag(relation)
      return relation if tag.blank?

      relation.joins(:tags).where(tags: { account_id: account.id, name: tag.downcase }).distinct
    end

    def normalize_positive_integer(value, fallback:)
      integer = Integer(value, exception: false)
      integer&.positive? ? integer : fallback
    end
  end
end
