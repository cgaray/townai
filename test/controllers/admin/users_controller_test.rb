require "test_helper"

module Admin
  class UsersControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:user)
      sign_in @admin
    end

    # Authorization tests
    test "redirects non-admin users to root" do
      sign_out :user
      sign_in @user
      get admin_users_url
      assert_redirected_to root_url
      assert_match(/not authorized/, flash[:alert])
    end

    test "redirects unauthenticated users to login" do
      sign_out :user
      get admin_users_url
      assert_redirected_to new_user_session_url
    end

    # Index tests
    test "should get index" do
      get admin_users_url
      assert_response :success
    end

    test "index displays users" do
      get admin_users_url
      assert_response :success
      assert_select "td", /#{Regexp.escape(@admin.email)}/
    end

    # New tests
    test "should get new" do
      get new_admin_user_url
      assert_response :success
    end

    test "new displays form" do
      get new_admin_user_url
      assert_response :success
      assert_select "form"
      assert_select "input[name='user[email]']"
    end

    # Create tests
    test "should create user" do
      assert_difference("User.count") do
        post admin_users_url, params: { user: { email: "newuser@example.com", admin: false } }
      end

      assert_redirected_to admin_users_url
      assert_match(/invited successfully/, flash[:notice])
    end

    test "should create admin user" do
      assert_difference("User.count") do
        post admin_users_url, params: { user: { email: "newadmin@example.com", admin: true } }
      end

      new_user = User.find_by(email: "newadmin@example.com")
      assert new_user.admin?
    end

    test "create with invalid email shows errors" do
      assert_no_difference("User.count") do
        post admin_users_url, params: { user: { email: "invalid-email", admin: false } }
      end

      assert_response :unprocessable_entity
    end

    test "create with duplicate email shows errors" do
      assert_no_difference("User.count") do
        post admin_users_url, params: { user: { email: @user.email, admin: false } }
      end

      assert_response :unprocessable_entity
    end

    # Edit tests
    test "should get edit" do
      get edit_admin_user_url(@user)
      assert_response :success
    end

    test "edit displays form with user data" do
      get edit_admin_user_url(@user)
      assert_response :success
      assert_select "input[name='user[email]'][value='#{@user.email}']"
    end

    # Update tests
    test "should update user" do
      patch admin_user_url(@user), params: { user: { email: "updated@example.com" } }
      assert_redirected_to admin_users_url
      assert_match(/updated successfully/, flash[:notice])

      @user.reload
      assert_equal "updated@example.com", @user.email
    end

    test "should update admin status" do
      assert_not @user.admin?

      patch admin_user_url(@user), params: { user: { admin: true } }
      assert_redirected_to admin_users_url

      @user.reload
      assert @user.admin?
    end

    test "update with invalid email shows errors" do
      patch admin_user_url(@user), params: { user: { email: "invalid-email" } }
      assert_response :unprocessable_entity
    end

    # Destroy tests
    test "should destroy user" do
      assert_difference("User.count", -1) do
        delete admin_user_url(@user)
      end

      assert_redirected_to admin_users_url
      assert_match(/deleted successfully/, flash[:notice])
    end

    test "cannot destroy own account" do
      assert_no_difference("User.count") do
        delete admin_user_url(@admin)
      end

      assert_redirected_to admin_users_url
      assert_match(/cannot delete your own account/, flash[:alert])
    end

    test "cannot remove own admin privileges" do
      patch admin_user_url(@admin), params: { user: { admin: "0" } }

      assert_redirected_to admin_users_url
      assert_match(/cannot remove your own admin privileges/, flash[:alert])

      @admin.reload
      assert @admin.admin?
    end

    # Send magic link tests
    test "should send magic link" do
      post send_magic_link_admin_user_url(@user)
      assert_redirected_to admin_users_url
      assert_match(/Login link sent/, flash[:notice])
    end
  end
end
