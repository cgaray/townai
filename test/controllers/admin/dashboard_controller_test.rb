# frozen_string_literal: true

require "test_helper"

module Admin
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:user)
      sign_in @admin
    end

    # Authorization tests
    test "redirects non-admin users to root" do
      sign_out :user
      sign_in @user
      get admin_root_url
      assert_redirected_to root_url
    end

    test "redirects unauthenticated users to login" do
      sign_out :user
      get admin_root_url
      assert_redirected_to new_user_session_url
    end

    # Index tests
    test "should get index" do
      get admin_root_url
      assert_response :success
    end

    test "index displays stats" do
      get admin_root_url
      assert_response :success
      assert_select ".stat", minimum: 4
    end

    test "index displays quick action cards" do
      get admin_root_url
      assert_response :success
      assert_select "a[href='#{admin_documents_path}']"
      assert_select "a[href='#{admin_people_path}']"
      assert_select "a[href='#{admin_users_path}']"
    end

    test "index displays recent activity section" do
      get admin_root_url
      assert_response :success
      assert_select "h2", /Recent Activity/
    end
  end
end
