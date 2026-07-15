class AnalyticsController < ApplicationController
  before_action :authenticate_user!

  def index
    @link = current_user.account.links.find(params[:link_id]) if params[:link_id]
    @analytics = Visits::Analytics.call(
      account: current_user.account,
      period: params[:period],
      timezone: current_user.profile.timezone,
      link: @link
    )
  end
end
