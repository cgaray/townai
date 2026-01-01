# frozen_string_literal: true

require "test_helper"

class AuthenticationLogTest < ActiveSupport::TestCase
  setup do
    @user = users(:admin)
  end

  test "should create valid authentication log with user" do
    log = AuthenticationLog.new(
      user: @user,
      action: "login_success",
      ip_address: "127.0.0.1",
      user_agent: "Test Browser"
    )
    assert log.valid?
    assert log.save
  end

  test "should create valid authentication log without user (failed login)" do
    log = AuthenticationLog.new(
      action: "login_failed",
      email_hash: Digest::SHA256.hexdigest("test@example.com"),
      ip_address: "127.0.0.1",
      user_agent: "Test Browser"
    )
    assert log.valid?
    assert log.save
  end

  test "requires action" do
    log = AuthenticationLog.new(
      user: @user,
      ip_address: "127.0.0.1"
    )
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "action_types constant contains expected values" do
    assert_includes AuthenticationLog::ACTION_TYPES, "login_success"
    assert_includes AuthenticationLog::ACTION_TYPES, "login_failed"
    assert_includes AuthenticationLog::ACTION_TYPES, "logout"
    assert_includes AuthenticationLog::ACTION_TYPES, "magic_link_used"
  end

  test "accepts all valid action types" do
    valid_actions = %w[login_success login_failed logout magic_link_used magic_link_failed password_reset_requested password_reset_completed]

    valid_actions.each do |action|
      log = AuthenticationLog.new(
        user: @user,
        action: action,
        ip_address: "127.0.0.1"
      )
      assert log.valid?, "Expected action '#{action}' to be valid"
    end
  end

  test "failed? returns true for failed actions" do
    failed_log = AuthenticationLog.new(action: "login_failed")
    assert failed_log.failed?

    magic_link_failed = AuthenticationLog.new(action: "magic_link_failed")
    assert magic_link_failed.failed?
  end

  test "failed? returns false for success actions" do
    success_log = AuthenticationLog.new(action: "login_success")
    assert_not success_log.failed?

    logout_log = AuthenticationLog.new(action: "logout")
    assert_not logout_log.failed?
  end

  test "action_display_name returns human readable string" do
    assert_equal "Successful login", AuthenticationLog.new(action: "login_success").action_display_name
    assert_equal "Failed login", AuthenticationLog.new(action: "login_failed").action_display_name
    assert_equal "Logged out", AuthenticationLog.new(action: "logout").action_display_name
    assert_equal "Magic link used", AuthenticationLog.new(action: "magic_link_used").action_display_name
  end

  test "recent scope orders by created_at desc" do
    old_log = AuthenticationLog.create!(
      user: @user,
      action: "login_success",
      ip_address: "127.0.0.1",
      created_at: 1.hour.ago
    )
    new_log = AuthenticationLog.create!(
      user: @user,
      action: "logout",
      ip_address: "127.0.0.1",
      created_at: Time.current
    )

    logs = AuthenticationLog.recent
    assert_equal new_log.id, logs.first.id
  end
end
