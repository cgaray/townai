# frozen_string_literal: true

require "test_helper"

class GoverningBodiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
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
end
