# frozen_string_literal: true

require "test_helper"

module Admin
  class SystemControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:user)
      sign_in @admin
    end

    # Authorization tests
    test "redirects non-admin users to root" do
      sign_out :user
      sign_in @user
      get admin_system_index_url
      assert_redirected_to root_url
    end

    test "redirects unauthenticated users to login" do
      sign_out :user
      get admin_system_index_url
      assert_redirected_to new_user_session_url
    end

    # Index tests
    test "should get index" do
      get admin_system_index_url
      assert_response :success
    end

    test "index displays stats" do
      get admin_system_index_url
      assert_response :success
      assert_select ".stat", minimum: 4
    end

    test "index displays rebuild search button" do
      get admin_system_index_url
      assert_response :success
      assert_select "form[action='#{rebuild_search_admin_system_index_path}']"
    end

    test "index displays clear cache button" do
      get admin_system_index_url
      assert_response :success
      assert_select "form[action='#{clear_cache_admin_system_index_path}']"
    end

    # Rebuild search tests
    test "should rebuild search index" do
      post rebuild_search_admin_system_index_url
      assert_redirected_to admin_system_index_url
      assert_match(/rebuilt successfully/, flash[:notice])
    end

    test "rebuild search enqueues audit log job" do
      assert_enqueued_with(job: AuditLogJob) do
        post rebuild_search_admin_system_index_url
      end
    end

    # Clear cache tests
    test "should clear cache" do
      post clear_cache_admin_system_index_url
      assert_redirected_to admin_system_index_url
      assert_match(/cleared successfully/, flash[:notice])
    end

    test "clear cache enqueues audit log job" do
      assert_enqueued_with(job: AuditLogJob) do
        post clear_cache_admin_system_index_url
      end
    end
  end
end
