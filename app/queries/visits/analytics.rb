module Visits
  class Analytics
    Result = Data.define(
      :period_days,
      :total_visits,
      :unique_visits,
      :visits_over_time,
      :top_links,
      :countries,
      :referrers,
      :browsers,
      :devices
    )

    def self.call(account:, period:, timezone:, link: nil)
      new(account:, period:, timezone:, link:).call
    end

    def initialize(account:, period:, timezone:, link:)
      @account = account
      @link = link
      @period_days = period.to_i == 7 ? 7 : 30
      @timezone = ActiveSupport::TimeZone[timezone] || ActiveSupport::TimeZone["UTC"]
    end

    def call
      Result.new(
        period_days:,
        total_visits: relation.count,
        unique_visits: unique_visits,
        visits_over_time: visits_over_time,
        top_links: top_links,
        countries: breakdown("country_code", "Unknown"),
        referrers: breakdown("referrer_host", "Direct / None"),
        browsers: breakdown("browser", "Unknown"),
        devices: breakdown("device_type", "Unknown")
      )
    end

    private

    attr_reader :account, :period_days, :timezone, :link

    def relation
      scoped = Visit.joins(:link)
        .where(links: { account_id: account.id })
        .where(occurred_at: period_start..Time.current)
      scoped = scoped.where(link:) if link
      @relation ||= scoped
    end

    def period_start
      Time.use_zone(timezone) { (period_days - 1).days.ago.beginning_of_day.utc }
    end

    def local_date_sql
      zone_name = ActiveRecord::Base.connection.quote(timezone.tzinfo.name)
      "DATE(visits.occurred_at AT TIME ZONE 'UTC' AT TIME ZONE #{zone_name})"
    end

    def unique_visits
      relation.pick(Arel.sql("COUNT(DISTINCT (#{local_date_sql}, visits.visitor_digest))")).to_i
    end

    def visits_over_time
      relation.group(Arel.sql(local_date_sql)).order(Arel.sql(local_date_sql)).count
    end

    def top_links
      relation.group("links.id", "links.name").order(Arel.sql("COUNT(*) DESC")).limit(5).count
    end

    def breakdown(column, blank_label)
      quoted_column = ActiveRecord::Base.connection.quote_column_name(column)
      label = ActiveRecord::Base.connection.quote(blank_label)
      expression = Arel.sql("COALESCE(NULLIF(visits.#{quoted_column}, ''), #{label})")
      relation.group(expression).order(Arel.sql("COUNT(*) DESC")).limit(10).count
    end
  end
end
