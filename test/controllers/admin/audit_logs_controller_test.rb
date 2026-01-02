# frozen_string_literal: true

require "test_helper"

module Admin
  class AuditLogsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:user)
      sign_in @admin

      # Create some audit logs for testing
      @admin_log = AdminAuditLog.create!(
        user: @admin,
        action: "user_create",
        resource_type: "User",
        resource_id: @user.id,
        ip_address: "127.0.0.1"
      )

      @auth_log = AuthenticationLog.create!(
        user: @admin,
        action: "login_success",
        ip_address: "127.0.0.1",
        user_agent: "Test Browser"
      )

      @doc_event = DocumentEventLog.create!(
        document: documents(:complete_agenda),
        event_type: "extraction_completed",
        metadata: { duration: 5.2 }.to_json
      )
    end

    # Authorization tests
    test "redirects non-admin users to root" do
      sign_out :user
      sign_in @user
      get admin_admin_logs_url
      assert_redirected_to root_url
    end

    test "redirects unauthenticated users to login" do
      sign_out :user
      get admin_admin_logs_url
      assert_redirected_to new_user_session_url
    end

    # Admin logs tests
    test "should get admin logs" do
      get admin_admin_logs_url
      assert_response :success
    end

    test "admin logs displays created log" do
      get admin_admin_logs_url
      assert_response :success
      assert_select "table"
      assert_match(/User Created/, response.body)
    end

    test "admin logs filters by action category" do
      get admin_admin_logs_url, params: { filter: "users" }
      assert_response :success
    end

    test "admin logs filters by user" do
      get admin_admin_logs_url, params: { user_id: @admin.id }
      assert_response :success
    end

    test "admin logs filters by date range" do
      get admin_admin_logs_url, params: { start_date: 1.day.ago.to_date, end_date: Date.current }
      assert_response :success
    end

    test "admin logs supports sorting" do
      get admin_admin_logs_url, params: { sort: "action", direction: "asc" }
      assert_response :success
    end

    # Authentication logs tests
    test "should get authentication logs" do
      get admin_authentication_logs_url
      assert_response :success
    end

    test "authentication logs displays created log" do
      get admin_authentication_logs_url
      assert_response :success
      assert_select "table"
      assert_match(/Successful login/, response.body)
    end

    test "authentication logs filters by action" do
      get admin_authentication_logs_url, params: { filter: "success" }
      assert_response :success
    end

    # Document events tests
    test "should get document events" do
      get admin_document_events_url
      assert_response :success
    end

    test "document events displays created log" do
      get admin_document_events_url
      assert_response :success
      assert_select "table"
      assert_match(/extraction_completed/, response.body)
    end

    test "document events filters by event type" do
      get admin_document_events_url, params: { filter: "completed" }
      assert_response :success
    end

    # Redirect test
    test "audit_logs redirects to admin_logs" do
      get admin_audit_logs_url
      assert_redirected_to admin_admin_logs_url
    end

    # Filter counts tests for refactored GROUP BY queries

    test "admin_log_filter_counts renders page with category counts" do
      AdminAuditLog.delete_all
      AdminAuditLog.create!(user: @admin, action: "user_create", resource_type: "User", resource_id: 1, ip_address: "127.0.0.1")
      AdminAuditLog.create!(user: @admin, action: "user_delete", resource_type: "User", resource_id: 2, ip_address: "127.0.0.1")
      AdminAuditLog.create!(user: @admin, action: "person_merge", resource_type: "Person", resource_id: 1, ip_address: "127.0.0.1")
      AdminAuditLog.create!(user: @admin, action: "document_delete", resource_type: "Document", resource_id: 1, ip_address: "127.0.0.1")
      AdminAuditLog.create!(user: @admin, action: "search_rebuild", resource_type: "System", resource_id: 0, ip_address: "127.0.0.1")

      get admin_admin_logs_url
      assert_response :success
      # Page renders with filter counts computed via GROUP BY
    end

    test "auth_log_filter_counts renders page with success/failed counts" do
      AuthenticationLog.delete_all
      AuthenticationLog.create!(user: @admin, action: "login_success", ip_address: "127.0.0.1", user_agent: "Test")
      AuthenticationLog.create!(user: @admin, action: "login_success", ip_address: "127.0.0.1", user_agent: "Test")
      AuthenticationLog.create!(user: @admin, action: "magic_link_used", ip_address: "127.0.0.1", user_agent: "Test")
      AuthenticationLog.create!(user: nil, action: "login_failed", ip_address: "127.0.0.1", user_agent: "Test", email_hash: "abc123")

      get admin_authentication_logs_url
      assert_response :success
      # Page renders with filter counts computed via GROUP BY
    end

    test "doc_event_filter_counts renders page with extraction counts" do
      DocumentEventLog.delete_all
      doc = documents(:complete_agenda)
      DocumentEventLog.create!(document: doc, event_type: "extraction_completed")
      DocumentEventLog.create!(document: doc, event_type: "extraction_completed")
      DocumentEventLog.create!(document: doc, event_type: "extraction_failed")
      DocumentEventLog.create!(document: doc, event_type: "extraction_started")
      DocumentEventLog.create!(document: doc, event_type: "uploaded")

      get admin_document_events_url
      assert_response :success
      # Page renders with filter counts computed via GROUP BY
    end

    # Additional sorting tests

    test "admin logs sorts by user column" do
      get admin_admin_logs_url, params: { sort: "user", direction: "asc" }
      assert_response :success
    end

    test "admin logs sorts by resource_type column" do
      get admin_admin_logs_url, params: { sort: "resource_type", direction: "desc" }
      assert_response :success
    end

    test "authentication logs sorts by ip_address column" do
      get admin_authentication_logs_url, params: { sort: "ip_address", direction: "desc" }
      assert_response :success
    end

    test "document events sorts by document column" do
      get admin_document_events_url, params: { sort: "document", direction: "asc" }
      assert_response :success
    end

    test "document events sorts by governing_body column" do
      get admin_document_events_url, params: { sort: "governing_body", direction: "desc" }
      assert_response :success
    end

    # Date range edge cases

    test "admin logs filters with only start_date" do
      get admin_admin_logs_url, params: { start_date: 1.week.ago.to_date.to_s }
      assert_response :success
    end

    test "admin logs filters with only end_date" do
      get admin_admin_logs_url, params: { end_date: Date.current.to_s }
      assert_response :success
    end

    test "admin logs handles invalid date gracefully" do
      get admin_admin_logs_url, params: { start_date: "invalid-date" }
      assert_response :success
    end
  end
end
