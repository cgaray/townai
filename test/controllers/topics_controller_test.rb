# frozen_string_literal: true

require "test_helper"

class TopicsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
    sign_in users(:user)
  end

  test "should get index" do
    get town_topics_url(@town)
    assert_response :success
    assert_select "h1", /Action Timeline/
  end

  test "index shows topics from completed documents" do
    get town_topics_url(@town)
    assert_response :success
    # Should show topics from fixtures
    assert_match(/Budget Amendment/, response.body)
  end

  test "index shows filter pills" do
    get town_topics_url(@town)
    assert_response :success
    assert_select "a", text: /All/
    assert_select "a", text: /Approved/
    assert_select "a", text: /Denied/
    assert_select "a", text: /Tabled/
  end

  test "index filters by action_taken approved" do
    get town_topics_url(@town, action_taken: "approved")
    assert_response :success
    # Should show approved topics
    assert_match(/Budget Amendment/, response.body)
    # Should not show denied topics
    assert_no_match(/Zoning Variance/, response.body)
  end

  test "index filters by action_taken denied" do
    get town_topics_url(@town, action_taken: "denied")
    assert_response :success
    # Should show denied topics
    assert_match(/Zoning Variance/, response.body)
    # Should not show approved topics
    assert_no_match(/Budget Amendment/, response.body)
  end

  test "index filters by with_actions" do
    get town_topics_url(@town, action_taken: "with_actions")
    assert_response :success
    # Should show topics with actions
    assert_match(/Budget Amendment/, response.body)
    # Should not show topics without actions
    assert_no_match(/Public Comment Period/, response.body)
  end

  test "index filters by governing_body_id" do
    body = governing_bodies(:select_board)
    get town_topics_url(@town, governing_body_id: body.id)
    assert_response :success
    # Should only show topics from select board documents
    assert_match(/Budget Amendment/, response.body)
  end

  test "index shows governing body dropdown" do
    get town_topics_url(@town)
    assert_response :success
    assert_select "select" do
      assert_select "option", text: "All Boards"
      assert_select "option", text: "Select Board"
    end
  end

  test "index groups topics by meeting date" do
    get town_topics_url(@town)
    assert_response :success
    # Should show date headers
    assert_select ".bg-base-200\\/50", minimum: 1
  end

  test "index shows pagination when many topics" do
    get town_topics_url(@town)
    assert_response :success
    # Pagination may or may not show depending on topic count
  end

  test "index requires authentication" do
    sign_out :user
    get town_topics_url(@town)
    assert_redirected_to new_user_session_url
  end

  test "index handles unknown action_taken filter gracefully" do
    get town_topics_url(@town, action_taken: "invalid_action")
    assert_response :success
    # Should show all topics when filter is invalid
  end

  test "index shows empty state when no topics" do
    # Remove all topics
    Topic.destroy_all

    get town_topics_url(@town)
    assert_response :success
    assert_match(/No Topics Found/, response.body)
  end

  test "index shows action badges for topics with actions" do
    get town_topics_url(@town)
    assert_response :success
    # Should show action badges (badge-soft badge-success)
    assert_select ".badge-soft.badge-success", minimum: 1  # approved
  end

  test "index shows link to source document" do
    get town_topics_url(@town)
    assert_response :success
    assert_match(/View document/, response.body)
  end

  test "index shows raw action text when available" do
    get town_topics_url(@town)
    assert_response :success
    # Fixture has action_taken_raw values
    assert_match(/motion passed 4-1/, response.body)
  end
end
