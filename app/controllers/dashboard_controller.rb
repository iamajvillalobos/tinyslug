class DashboardController < ApplicationController
  RECENT_LINKS_LIMIT = 5

  before_action :authenticate_user!

  def show
    account = current_user.account
    @links_count = account.links.count
    @recent_links = account.links.includes(:custom_domain).order(created_at: :desc).limit(RECENT_LINKS_LIMIT)
    @weekly_visits = Visits::Analytics.call(
      account:,
      period: 7,
      timezone: current_user.profile.timezone
    ).total_visits
  end
end
