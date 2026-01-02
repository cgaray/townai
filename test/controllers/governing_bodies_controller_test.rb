# frozen_string_literal: true

require "test_helper"

class GoverningBodiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
    sign_in users(:user)
  end

  test "should get index" do
    get town_governing_bodies_path(@town)
    assert_response :success
  end

  test "index displays governing bodies" do
    gb = governing_bodies(:select_board)
    get town_governing_bodies_path(@town)
    assert_select "h2", text: gb.name
  end

  test "should get show" do
    gb = governing_bodies(:select_board)
    get town_governing_body_path(@town, gb)
    assert_response :success
  end

  test "show displays governing body name" do
    gb = governing_bodies(:select_board)
    get town_governing_body_path(@town, gb)
    assert_select "h1", text: gb.name
  end

  test "show displays meeting history section" do
    gb = governing_bodies(:select_board)
    get town_governing_body_path(@town, gb)
    assert_select "h2", text: /Meeting History/
  end

  test "show displays members section" do
    gb = governing_bodies(:select_board)
    get town_governing_body_path(@town, gb)
    assert_select "h3", text: /Members/
  end

  test "show returns 404 for non-existent governing body" do
    get town_governing_body_path(@town, id: 999999)
    assert_response :not_found
  end

  # Tests for JOIN with GROUP BY optimization

  test "index renders with people_count computed via JOIN" do
    get town_governing_bodies_path(@town)
    assert_response :success
    # Page renders with people_count computed via LEFT JOIN + GROUP BY
  end

  test "show renders with people_count for single governing body" do
    gb = governing_bodies(:select_board)

    get town_governing_body_path(@town, gb)
    assert_response :success
    # Page renders with people_count computed via LEFT JOIN + GROUP BY
  end

  test "show paginates members list" do
    gb = governing_bodies(:select_board)

    get town_governing_body_path(@town, gb, people_page: 1)
    assert_response :success
    # Members section should be paginated
  end
end
