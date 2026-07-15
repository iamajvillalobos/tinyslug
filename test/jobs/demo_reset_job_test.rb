require "test_helper"

class DemoResetJobTest < ActiveJob::TestCase
  setup do
    @original_setting = Rails.configuration.x.demo_mode_enabled
  end

  teardown do
    Rails.configuration.x.demo_mode_enabled = @original_setting
  end

  test "wipes all user data and restores demo seeds when demo mode is on" do
    Rails.configuration.x.demo_mode_enabled = true
    existing_account = accounts(:alice)
    existing_user = users(:alice)
    existing_link = links(:alice_docs)

    DemoResetJob.perform_now

    assert_not Account.exists?(existing_account.id)
    assert_not User.exists?(existing_user.id)
    assert_not Link.exists?(existing_link.id)
    assert_equal 0, CustomDomain.count
    assert_equal 0, ApiToken.count

    demo_user = User.find_by(email: "demo@tinyslug.local")
    assert demo_user, "expected demo seed user to be restored"
    assert demo_user.account.links.exists?(slug: "demo-docs")

    demo_link_ids = demo_user.account.links.ids
    assert_operator Visit.count, :>, 0, "expected demo seed visits to be restored"
    assert_equal 0, Visit.where.not(link_id: demo_link_ids).count
    assert_equal 0, Tagging.where.not(link_id: demo_link_ids).count
  end

  test "removes orphaned tags left without an account" do
    Rails.configuration.x.demo_mode_enabled = true

    DemoResetJob.perform_now

    demo_account = User.find_by!(email: "demo@tinyslug.local").account
    assert_operator Tag.count, :>, 0, "expected demo seed tags to be restored"
    assert_equal 0, Tag.where.not(account_id: demo_account.id).count
  end

  test "does nothing when demo mode is off" do
    Rails.configuration.x.demo_mode_enabled = false

    assert_no_difference [ "Account.count", "User.count", "Link.count", "Tag.count" ] do
      DemoResetJob.perform_now
    end

    assert User.exists?(users(:alice).id)
    assert_nil User.find_by(email: "demo@tinyslug.local")
  end
end
