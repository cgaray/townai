# frozen_string_literal: true

require "test_helper"

class TownsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
    sign_in users(:user)
  end

  test "should get index" do
    get towns_url
    assert_response :success
  end

  test "index displays towns" do
    get towns_url
    assert_response :success
    assert_select "h2", text: @town.name
  end

  test "should get show" do
    get town_url(@town)
    assert_response :success
  end

  test "show displays dashboard heading" do
    get town_url(@town)
    assert_response :success
    assert_select "h1", text: "Dashboard"
    # Town name appears in sidebar
    assert_select ".text-gradient-primary", text: @town.name
  end

  test "show displays quick links" do
    get town_url(@town)
    assert_response :success
    assert_select "h3", text: "Documents"
    assert_select "h3", text: "Governing Bodies"
    assert_select "h3", text: "People"
  end

  test "show returns 404 for non-existent town" do
    get town_url(slug: "nonexistent")
    assert_response :not_found
  end

  test "redirects to login when not authenticated" do
    sign_out :user
    get towns_url
    assert_redirected_to new_user_session_url
  end
end
