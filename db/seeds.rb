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

  docs_link = user.account.links.find_or_initialize_by(slug: "demo-docs")
  docs_link.assign_attributes(
    name: "Tinyslug documentation",
    destination_url: "https://github.com/",
    tracking_enabled: false,
    source: :dashboard
  )
  docs_link.save!

  puts "Seeded demo@tinyslug.local for local verification (see README for credentials)."
end
