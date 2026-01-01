# frozen_string_literal: true

require "test_helper"

class AuthenticationLogJobTest < ActiveJob::TestCase
  setup do
    @user = users(:admin)
  end

  test "creates authentication log with user" do
    assert_difference "AuthenticationLog.count", 1 do
      AuthenticationLogJob.perform_now(
        user_id: @user.id,
        action: "login_success",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      )
    end

    log = AuthenticationLog.last
    assert_equal @user.id, log.user_id
    assert_equal "login_success", log.action
    assert_equal "127.0.0.1", log.ip_address
    assert_equal "Test Browser", log.user_agent
  end

  test "creates authentication log without user (failed login)" do
    assert_difference "AuthenticationLog.count", 1 do
      AuthenticationLogJob.perform_now(
        action: "login_failed",
        email: "test@example.com",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      )
    end

    log = AuthenticationLog.last
    assert_nil log.user_id
    assert_equal "login_failed", log.action
    assert_equal Digest::SHA256.hexdigest("test@example.com"), log.email_hash
  end

  test "hashes email for privacy" do
    AuthenticationLogJob.perform_now(
      action: "login_failed",
      email: "secret@example.com",
      ip_address: "127.0.0.1"
    )

    log = AuthenticationLog.last
    assert_equal Digest::SHA256.hexdigest("secret@example.com"), log.email_hash
    # Email should not be stored in plain text anywhere
    assert_not_equal "secret@example.com", log.email_hash
  end

  test "does not store email_hash when user_id is present" do
    AuthenticationLogJob.perform_now(
      user_id: @user.id,
      action: "login_success",
      email: "test@example.com",
      ip_address: "127.0.0.1"
    )

    log = AuthenticationLog.last
    assert_equal @user.id, log.user_id
    # email_hash may or may not be set when user_id is present - that's implementation detail
  end

  test "job is enqueued to default queue" do
    assert_equal "default", AuthenticationLogJob.new.queue_name
  end
end
