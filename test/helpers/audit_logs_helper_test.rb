# frozen_string_literal: true

require "test_helper"
require "ostruct"

class AuditLogsHelperTest < ActionView::TestCase
  include IconsHelper

  # Admin action badge tests
  test "admin_action_badge returns nil for blank action" do
    assert_nil admin_action_badge(nil)
    assert_nil admin_action_badge("")
  end

  test "admin_action_badge renders badge with correct label for known action" do
    badge = admin_action_badge("user_create")
    assert_match(/User Created/, badge)
    assert_match(/badge-ghost/, badge)
  end

  test "admin_action_badge renders error badge for destructive actions" do
    badge = admin_action_badge("user_delete")
    assert_match(/User Deleted/, badge)
    assert_match(/badge-error/, badge)
  end

  test "admin_action_badge renders humanized label for unknown action" do
    badge = admin_action_badge("some_unknown_action")
    assert_match(/Some unknown action/, badge)
    assert_match(/badge-ghost/, badge)
  end

  # Admin action border class tests
  test "admin_action_border_class returns correct class for user actions" do
    assert_equal "border-l-user-action", admin_action_border_class("user_create")
    assert_equal "border-l-user-action", admin_action_border_class("user_delete")
  end

  test "admin_action_border_class returns correct class for person actions" do
    assert_equal "border-l-person-action", admin_action_border_class("person_merge")
  end

  test "admin_action_border_class returns correct class for document actions" do
    assert_equal "border-l-document-action", admin_action_border_class("document_retry")
  end

  test "admin_action_border_class returns empty string for unknown action" do
    assert_equal "", admin_action_border_class("unknown_action")
  end

  # Auth status badge tests
  test "auth_status_badge renders success badge for successful login" do
    log = OpenStruct.new(success?: true, failed?: false, action_display_name: "Successful login")
    badge = auth_status_badge(log)
    assert_match(/badge-success/, badge)
    assert_match(/Successful login/, badge)
  end

  test "auth_status_badge renders error badge for failed login" do
    log = OpenStruct.new(success?: false, failed?: true, action_display_name: "Failed login")
    badge = auth_status_badge(log)
    assert_match(/badge-error/, badge)
    assert_match(/Failed login/, badge)
  end

  test "auth_status_badge renders ghost badge for neutral events" do
    log = OpenStruct.new(success?: false, failed?: false, action_display_name: "Logged out")
    badge = auth_status_badge(log)
    assert_match(/badge-ghost/, badge)
    assert_match(/Logged out/, badge)
  end

  # Auth status border class tests
  test "auth_status_border_class returns correct class for success" do
    log = OpenStruct.new(success?: true, failed?: false)
    assert_equal "border-l-auth-success", auth_status_border_class(log)
  end

  test "auth_status_border_class returns correct class for failed" do
    log = OpenStruct.new(success?: false, failed?: true)
    assert_equal "border-l-auth-failed", auth_status_border_class(log)
  end

  # Doc event badge tests
  test "doc_event_badge renders success badge for successful extraction" do
    log = OpenStruct.new(success?: true, failure?: false, event_type: "extraction_completed")
    badge = doc_event_badge(log)
    assert_match(/badge-success/, badge)
    assert_match(/Extraction completed/, badge)
  end

  test "doc_event_badge renders error badge for failed extraction" do
    log = OpenStruct.new(success?: false, failure?: true, event_type: "extraction_failed")
    badge = doc_event_badge(log)
    assert_match(/badge-error/, badge)
    assert_match(/Extraction failed/, badge)
  end

  # Doc event border class tests
  test "doc_event_border_class returns correct class for success" do
    log = OpenStruct.new(success?: true, failure?: false)
    assert_equal "border-l-doc-success", doc_event_border_class(log)
  end

  test "doc_event_border_class returns correct class for failure" do
    log = OpenStruct.new(success?: false, failure?: true)
    assert_equal "border-l-doc-failure", doc_event_border_class(log)
  end
end
