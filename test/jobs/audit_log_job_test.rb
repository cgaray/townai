# frozen_string_literal: true

require "test_helper"

class AuditLogJobTest < ActiveJob::TestCase
  setup do
    @user = users(:admin)
  end

  test "creates admin audit log" do
    assert_difference "AdminAuditLog.count", 1 do
      AuditLogJob.perform_now(
        user: @user,
        action: "user_create",
        resource_type: "User",
        resource_id: 123,
        ip_address: "127.0.0.1"
      )
    end
  end

  test "creates audit log with all attributes" do
    previous_state = { email: "old@example.com" }.to_json
    new_state = { email: "new@example.com" }.to_json
    params = { id: 123 }.to_json

    AuditLogJob.perform_now(
      user: @user,
      action: "user_update",
      resource_type: "User",
      resource_id: 123,
      previous_state: previous_state,
      new_state: new_state,
      ip_address: "192.168.1.1",
      params: params
    )

    log = AdminAuditLog.last
    assert_equal @user.id, log.user_id
    assert_equal "user_update", log.action
    assert_equal "User", log.resource_type
    assert_equal 123, log.resource_id
    assert_equal previous_state, log.previous_state
    assert_equal new_state, log.new_state
    assert_equal "192.168.1.1", log.ip_address
    assert_equal params, log.params
  end

  test "creates audit log without optional attributes" do
    assert_difference "AdminAuditLog.count", 1 do
      AuditLogJob.perform_now(
        user: @user,
        action: "cache_clear",
        resource_type: "System"
      )
    end

    log = AdminAuditLog.last
    assert_nil log.resource_id
    assert_nil log.previous_state
    assert_nil log.new_state
    assert_nil log.ip_address
  end

  test "job is enqueued to default queue" do
    assert_equal "default", AuditLogJob.new.queue_name
  end
end
