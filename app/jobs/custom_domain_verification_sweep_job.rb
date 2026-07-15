class CustomDomainVerificationSweepJob < ApplicationJob
  queue_as :background

  def perform
    CustomDomain.where(status: %i[pending failed]).find_each do |custom_domain|
      CustomDomainVerificationJob.perform_later(custom_domain.id)
    end
  end
end
