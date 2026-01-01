# frozen_string_literal: true

require "test_helper"

class AdminAuditLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
  end

  test "should create valid audit log" do
    log = AdminAuditLog.new(
      user: @user,
      action: "user_create",
      resource_type: "User",
      resource_id: 1,
      ip_address: "127.0.0.1"
    )
    assert log.valid?
    assert log.save
  end

  test "requires user" do
    log = AdminAuditLog.new(
      action: "user_create",
      resource_type: "User"
    )
    assert_not log.valid?
    assert_includes log.errors[:user], "must exist"
  end

  test "requires action" do
    log = AdminAuditLog.new(
      user: @user,
      resource_type: "User"
    )
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "requires resource_type" do
    log = AdminAuditLog.new(
      user: @user,
      action: "user_create"
    )
    assert_not log.valid?
    assert_includes log.errors[:resource_type], "can't be blank"
  end

  test "resource_id is optional" do
    log = AdminAuditLog.new(
      user: @user,
      action: "cache_clear",
      resource_type: "System"
    )
    assert log.valid?
  end

  test "stores previous_state as JSON" do
    log = AdminAuditLog.create!(
      user: @user,
      action: "user_update",
      resource_type: "User",
      resource_id: 1,
      previous_state: { email: "old@example.com" }.to_json
    )

    parsed = JSON.parse(log.previous_state)
    assert_equal "old@example.com", parsed["email"]
  end

  test "stores new_state as JSON" do
    log = AdminAuditLog.create!(
      user: @user,
      action: "user_update",
      resource_type: "User",
      resource_id: 1,
      new_state: { email: "new@example.com" }.to_json
    )

    parsed = JSON.parse(log.new_state)
    assert_equal "new@example.com", parsed["email"]
  end

  test "previous_state_parsed returns parsed JSON" do
    log = AdminAuditLog.create!(
      user: @user,
      action: "user_update",
      resource_type: "User",
      previous_state: { email: "old@example.com" }.to_json
    )

    parsed = log.previous_state_parsed
    assert_equal "old@example.com", parsed["email"]
  end

  test "new_state_parsed returns parsed JSON" do
    log = AdminAuditLog.create!(
      user: @user,
      action: "user_update",
      resource_type: "User",
      new_state: { email: "new@example.com" }.to_json
    )

    parsed = log.new_state_parsed
    assert_equal "new@example.com", parsed["email"]
  end

  test "recent scope orders by created_at desc" do
    old_log = AdminAuditLog.create!(
      user: @user,
      action: "test1",
      resource_type: "Test",
      created_at: 1.hour.ago
    )
    new_log = AdminAuditLog.create!(
      user: @user,
      action: "test2",
      resource_type: "Test",
      created_at: Time.current
    )

    logs = AdminAuditLog.recent
    assert_equal new_log.id, logs.first.id
  end
end
