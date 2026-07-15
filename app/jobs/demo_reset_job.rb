class DemoResetJob < ApplicationJob
  queue_as :background

  # Deleting accounts cascades through dependent: :destroy to users, profiles,
  # links, visits, taggings, tags, custom domains, and API tokens. The sweep
  # afterwards removes any orphans, ordered so foreign keys are never violated.
  ORPHAN_SWEEP_ORDER = %w[Visit Tagging Tag Profile User Link ApiToken CustomDomain Account].freeze

  def perform
    unless Rails.configuration.x.demo_mode_enabled
      Rails.logger.info("DemoResetJob skipped: DEMO_MODE_ENABLED is off")
      return
    end

    wiped = wipe_all_data
    Rails.application.load_seed

    summary = wiped.map { |name, count| "#{count} #{name.underscore.pluralize}" }.join(", ")
    Rails.logger.info("DemoResetJob wiped #{summary}; demo seed data restored")
  end

  private

  def wipe_all_data
    counts = ORPHAN_SWEEP_ORDER.index_with { |name| name.constantize.count }

    # Every account is recreated by the seed data reload, so it is safe to
    # delete everything here.
    Account.destroy_all
    ORPHAN_SWEEP_ORDER.each { |name| name.constantize.delete_all }

    counts
  end
end
