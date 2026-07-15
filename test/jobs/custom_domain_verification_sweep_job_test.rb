require "test_helper"

class CustomDomainVerificationSweepJobTest < ActiveJob::TestCase
  test "enqueues pending and failed domains but skips verified domains" do
    custom_domains(:alice_pending).update!(status: :failed)

    assert_enqueued_jobs 1, only: CustomDomainVerificationJob do
      CustomDomainVerificationSweepJob.perform_now
    end

    job_arguments = enqueued_jobs.filter_map do |job|
      job.fetch(:args).first if job.fetch(:job) == CustomDomainVerificationJob
    end
    assert_includes job_arguments, custom_domains(:alice_pending).id
    assert_not_includes job_arguments, custom_domains(:alice_verified).id
  end
end
