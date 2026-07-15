if Rails.env.production? && !Rails.configuration.x.demo_mode_enabled
  puts "No production seed data is required."
else
  demo_password = ENV.fetch("SEED_DEMO_PASSWORD", "demo-password-change-me")
  user = User.find_or_initialize_by(email: "demo@tinyslug.local")

  if user.new_record?
    user.username = "demo"
    user.password = demo_password
    user.password_confirmation = demo_password
    user.skip_confirmation!
    user.save!
  end

  user.profile.update!(
    first_name: "Tiny",
    last_name: "Slug",
    timezone: "UTC"
  )

  account = user.account

  tags = %w[work writing talks personal].index_with do |name|
    account.tags.find_or_create_by!(name: name)
  end

  link_definitions = [
    {
      slug: "demo-docs",
      name: "tinyslug documentation",
      destination_url: "https://github.com/iamajvillalobos/tinyslug#readme",
      tracking_enabled: false,
      tags: %w[work]
    },
    {
      slug: "useful-writing",
      name: "Blog post: How to write usefully",
      destination_url: "https://paulgraham.com/useful.html",
      tracking_enabled: true,
      tags: %w[writing]
    },
    {
      slug: "rails-repo",
      name: "Ruby on Rails source on GitHub",
      destination_url: "https://github.com/rails/rails",
      tracking_enabled: true,
      tags: %w[work]
    },
    {
      slug: "rails-world-keynote",
      name: "Rails World keynote recording",
      destination_url: "https://www.youtube.com/watch?v=-cEn_83zRFw",
      tracking_enabled: true,
      tags: %w[talks]
    },
    {
      slug: "newsletter",
      name: "Monthly newsletter signup",
      destination_url: "https://buttondown.com/tinyslug",
      tracking_enabled: true,
      tags: %w[writing]
    },
    {
      slug: "privacy-slides",
      name: "Slides: Privacy-first link analytics",
      destination_url: "https://speakerdeck.com/",
      tracking_enabled: true,
      tags: %w[talks work]
    },
    {
      slug: "sqlite-paper",
      name: "SQLite: Past, Present, and Future (PDF)",
      destination_url: "https://www.vldb.org/pvldb/vol15/p3535-gaffney.pdf",
      tracking_enabled: false,
      tags: %w[work]
    },
    {
      slug: "studio-map",
      name: "Directions to the studio",
      destination_url: "https://www.google.com/maps/place/Ferry+Building,+San+Francisco",
      tracking_enabled: false,
      tags: %w[personal]
    },
    {
      slug: "reading-list",
      name: "Summer reading list",
      destination_url: "https://www.goodreads.com/list/show/1.Best_Books_Ever",
      tracking_enabled: false,
      tags: %w[personal]
    },
    {
      slug: "v60-guide",
      name: "V60 pour-over brew guide",
      destination_url: "https://www.youtube.com/watch?v=AI4ynXzkSQo",
      tracking_enabled: false,
      tags: %w[personal]
    }
  ]

  links = link_definitions.index_by { |definition| definition[:slug] }.transform_values do |definition|
    link = account.links.find_or_initialize_by(slug: definition[:slug])
    link.assign_attributes(
      name: definition[:name],
      destination_url: definition[:destination_url],
      tracking_enabled: definition[:tracking_enabled],
      source: :dashboard
    )
    link.save!
    link.tags = tags.values_at(*definition[:tags])
    link
  end

  # Regenerate demo visits from a fixed RNG seed so repeated runs stay
  # deterministic while the 30-day window keeps tracking the current date.
  # Rows mirror what Visits::PayloadBuilder + RecordVisitJob persist: coarse
  # browser/device/country/referrer fields and an HMAC visitor digest.
  link_weights = {
    "useful-writing" => 34,
    "rails-repo" => 26,
    "rails-world-keynote" => 17,
    "newsletter" => 13,
    "privacy-slides" => 10
  }
  country_weights = {
    "US" => 30, "DE" => 14, "GB" => 12, "NL" => 8, "CA" => 8,
    "FR" => 7, "IN" => 7, "BR" => 5, "AU" => 5, "ES" => 4
  }
  referrer_weights = {
    nil => 32, "news.ycombinator.com" => 16, "www.google.com" => 15,
    "t.co" => 10, "github.com" => 9, "www.linkedin.com" => 7,
    "duckduckgo.com" => 6, "mastodon.social" => 5
  }
  client_weights = {
    [ "Chrome", "desktop" ] => 30,
    [ "Mobile Safari", "smartphone" ] => 18,
    [ "Chrome Mobile", "smartphone" ] => 14,
    [ "Safari", "desktop" ] => 12,
    [ "Firefox", "desktop" ] => 10,
    [ "Microsoft Edge", "desktop" ] => 8,
    [ "Samsung Internet", "smartphone" ] => 4,
    [ "Safari", "tablet" ] => 4
  }

  rng = Random.new(1_129)
  weighted_pick = lambda do |weights|
    roll = rng.rand(weights.values.sum)
    weights.find { |_value, weight| (roll -= weight) < 0 }.first
  end

  now = Time.current
  visit_rows = []

  30.times do |day_index|
    day_start = (29 - day_index).days.ago.beginning_of_day
    day_end = [ day_start.end_of_day, now - 1.minute ].min
    next if day_end <= day_start

    visits_today = 2 + (day_index * 0.35).round + rng.rand(0..3)
    visits_today.times do
      link = links.fetch(weighted_pick.call(link_weights))
      browser, device_type = weighted_pick.call(client_weights)
      occurred_at = Time.zone.at(rng.rand(day_start.to_f..day_end.to_f)).utc
      digest_material = [
        link.id,
        occurred_at.to_date.iso8601,
        "network-#{rng.rand(1..12)}",
        "#{browser}|#{device_type}"
      ].join("|")

      visit_rows << {
        link_id: link.id,
        event_key: "seed-visit-#{visit_rows.length + 1}",
        visitor_digest: OpenSSL::HMAC.hexdigest("SHA256", "tinyslug-demo-seed", digest_material),
        browser: browser,
        device_type: device_type,
        country_code: weighted_pick.call(country_weights),
        referrer_host: weighted_pick.call(referrer_weights),
        occurred_at: occurred_at
      }
    end
  end

  Visit.where(link_id: account.links.select(:id)).delete_all
  Visit.insert_all!(visit_rows)

  puts "Seeded demo@tinyslug.local with #{links.size} links, #{tags.size} tags, " \
    "and #{visit_rows.size} visits (see README for credentials)."
end
