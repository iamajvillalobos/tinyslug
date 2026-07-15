class CustomDomainVerificationJob < ApplicationJob
  queue_as :background

  discard_on ActiveRecord::RecordNotFound

  def perform(custom_domain_id)
    CustomDomains::Verify.call(custom_domain: CustomDomain.find(custom_domain_id))
  end
end
