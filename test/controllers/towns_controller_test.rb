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

  # Tests for cached town_stats

  test "show renders with town_stats" do
    get town_url(@town)
    assert_response :success
    # Page renders with town_stats computed
  end

  test "show caches town_stats when cache store is enabled" do
    # Use memory store for this test to verify caching logic
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    Rails.cache.clear

    get town_url(@town)
    assert_response :success

    # Verify cache was written
    cached = Rails.cache.read("town_stats/#{@town.id}")
    assert_not_nil cached
    assert cached.key?(:documents_count)
    assert cached.key?(:topics_count)
  ensure
    Rails.cache = original_cache
  end

  test "show uses consistent cache key format" do
    # Use memory store for this test to verify cache key format
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new

    Rails.cache.clear

    get town_url(@town)
    assert_response :success

    # Cache key should match TownScoped concern format
    assert Rails.cache.exist?("town_stats/#{@town.id}")
  ensure
    Rails.cache = original_cache
  end
end
