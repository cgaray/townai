# frozen_string_literal: true

require "test_helper"

class CleanupLogsJobTest < ActiveJob::TestCase
  setup do
    @user = users(:admin)
    @document = documents(:complete_agenda)
  end

  test "deletes admin audit logs older than 90 days" do
    old_log = AdminAuditLog.create!(
      user: @user,
      action: "test",
      resource_type: "Test",
      created_at: 91.days.ago
    )
    recent_log = AdminAuditLog.create!(
      user: @user,
      action: "test",
      resource_type: "Test",
      created_at: 89.days.ago
    )

    CleanupLogsJob.perform_now

    assert_nil AdminAuditLog.find_by(id: old_log.id)
    assert_not_nil AdminAuditLog.find_by(id: recent_log.id)
  end

  test "deletes authentication logs older than 90 days" do
    old_log = AuthenticationLog.create!(
      user: @user,
      action: "login_success",
      ip_address: "127.0.0.1",
      created_at: 91.days.ago
    )
    recent_log = AuthenticationLog.create!(
      user: @user,
      action: "login_success",
      ip_address: "127.0.0.1",
      created_at: 89.days.ago
    )

    CleanupLogsJob.perform_now

    assert_nil AuthenticationLog.find_by(id: old_log.id)
    assert_not_nil AuthenticationLog.find_by(id: recent_log.id)
  end

  test "deletes document event logs older than 1 year" do
    old_log = DocumentEventLog.create!(
      document: @document,
      event_type: "extraction_completed",
      created_at: 366.days.ago
    )
    recent_log = DocumentEventLog.create!(
      document: @document,
      event_type: "extraction_completed",
      created_at: 364.days.ago
    )

    CleanupLogsJob.perform_now

    assert_nil DocumentEventLog.find_by(id: old_log.id)
    assert_not_nil DocumentEventLog.find_by(id: recent_log.id)
  end

  test "returns count of deleted records" do
    AdminAuditLog.create!(user: @user, action: "test", resource_type: "Test", created_at: 91.days.ago)
    AdminAuditLog.create!(user: @user, action: "test", resource_type: "Test", created_at: 91.days.ago)
    AuthenticationLog.create!(user: @user, action: "login_success", ip_address: "127.0.0.1", created_at: 91.days.ago)

    results = CleanupLogsJob.perform_now

    assert_equal 2, results["AdminAuditLog"]
    assert_equal 1, results["AuthenticationLog"]
    assert_equal 0, results["DocumentEventLog"]
  end

  test "job is enqueued to default queue" do
    assert_equal "default", CleanupLogsJob.new.queue_name
  end
end
