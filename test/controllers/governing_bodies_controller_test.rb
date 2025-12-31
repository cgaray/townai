# frozen_string_literal: true

require "test_helper"

class GoverningBodiesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get governing_bodies_path
    assert_response :success
  end

  test "index displays governing bodies" do
    gb = governing_bodies(:select_board)
    get governing_bodies_path
    assert_select "h2", text: gb.name
  end

  test "should get show" do
    gb = governing_bodies(:select_board)
    get governing_body_path(gb)
    assert_response :success
  end

  test "show displays governing body name" do
    gb = governing_bodies(:select_board)
    get governing_body_path(gb)
    assert_select "h1", text: gb.name
  end

  test "show displays meeting history section" do
    gb = governing_bodies(:select_board)
    get governing_body_path(gb)
    assert_select "h2", text: /Meeting History/
  end

  test "show displays members section" do
    gb = governing_bodies(:select_board)
    get governing_body_path(gb)
    assert_select "h3", text: /Members/
  end

  test "show returns 404 for non-existent governing body" do
    get governing_body_path(id: 999999)
    assert_response :not_found
  end
end
