# frozen_string_literal: true

require "test_helper"

class TownScopedTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
  end

  test "sets current_town from town_slug parameter" do
    get town_documents_path(@town)
    assert_response :success
  end

  test "redirects to towns_path when town not found" do
    get town_documents_path(town_slug: "nonexistent-town")
    assert_redirected_to towns_path
    assert_equal "Town not found", flash[:alert]
  end

  test "town_stats are computed for valid town" do
    get town_documents_path(@town)
    assert_response :success
    # Verify the page renders without errors (stats are used in layout)
    assert_select "body"
  end

  test "nested resources use current_town" do
    document = documents(:complete_agenda)
    get town_document_path(@town, document)
    assert_response :success
  end

  test "governing bodies index uses current_town" do
    get town_governing_bodies_path(@town)
    assert_response :success
  end

  test "people index uses current_town" do
    get town_people_path(@town)
    assert_response :success
  end
end
