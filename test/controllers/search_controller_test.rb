# frozen_string_literal: true

require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
    SearchEntry.clear_all!
    sign_in users(:user)
  end

  test "global search renders search page" do
    get global_search_path
    assert_response :success
    assert_select "input[name='q']"
  end

  test "town search renders search page" do
    get town_search_path(@town)
    assert_response :success
    assert_select "input[name='q']"
  end

  test "show with query returns results page" do
    # Index a test document
    doc = documents(:complete_agenda)
    SearchIndexer.index_document(doc)

    get global_search_path(q: "meeting")
    assert_response :success
  end

  test "show with type filter" do
    doc = documents(:complete_agenda)
    SearchIndexer.index_document(doc)

    get global_search_path(q: "meeting", type: "document")
    assert_response :success
  end

  test "quick returns JSON" do
    get global_search_quick_path(q: "test")
    assert_response :success
    json = JSON.parse(response.body)
    assert_includes json.keys, "results"
    assert_includes json.keys, "counts"
    assert_includes json.keys, "total"
  end

  test "quick with empty query returns empty results" do
    get global_search_quick_path(q: "")
    assert_response :success
    json = JSON.parse(response.body)
    assert_equal [], json["results"]
    assert_equal 0, json["total"]
  end

  test "quick with type filter" do
    get global_search_quick_path(q: "test", type: "document")
    assert_response :success
    json = JSON.parse(response.body)
    assert json.key?("results")
  end
end
