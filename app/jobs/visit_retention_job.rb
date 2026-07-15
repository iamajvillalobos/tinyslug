class VisitRetentionJob < ApplicationJob
  queue_as :background

  def perform(retention_days: Rails.configuration.x.redirect_visit_retention_days)
    retention_days = Integer(retention_days, exception: false) || 90
    Visit.where(occurred_at: ...retention_days.days.ago).delete_all
  end
end
