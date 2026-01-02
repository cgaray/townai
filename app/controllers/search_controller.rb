# frozen_string_literal: true

class SearchController < ApplicationController
  before_action :set_current_town

  # GET /search or /towns/:town_slug/search - Full search results page
  def show
    @query = params[:q].to_s.strip
    @type = params[:type]

    if @query.present?
      types = @type.present? ? [ @type ] : nil
      @results = SearchEntry.search(@query, types: types, limit: 50)
      @counts = SearchEntry.counts_by_type(@query)
      @total_count = @counts.values.sum
    else
      @results = []
      @counts = {}
      @total_count = 0
    end
  rescue StandardError => e
    Rails.logger.error("[SearchController] Search error: #{e.message}")
    @results = []
    @counts = {}
    @total_count = 0
    flash.now[:alert] = "Search encountered an error. Please try a simpler query."
  end

  # GET /search/quick or /towns/:town_slug/search/quick - Quick results for modal (JSON)
  def quick
    query = params[:q].to_s.strip
    type = params[:type]

    if query.present?
      types = type.present? ? [ type ] : nil
      results = SearchEntry.search(query, types: types, limit: 8)
      counts = SearchEntry.counts_by_type(query)

      render json: {
        results: results,
        counts: counts,
        total: counts.values.sum
      }
    else
      render json: { results: [], counts: {}, total: 0 }
    end
  rescue StandardError => e
    Rails.logger.error("[SearchController] Quick search error: #{e.message}")
    render json: { results: [], counts: {}, total: 0, error: "Search failed" }
  end

  private

  # Set current_town from params if present, otherwise nil (global search)
  def set_current_town
    @current_town = Town.find_by(slug: params[:town_slug]) if params[:town_slug].present?
  end

  def current_town
    @current_town
  end
  helper_method :current_town

  # Helper to build search paths with proper town scoping
  def search_path_for(params = {})
    if @current_town
      town_search_path(@current_town, params)
    else
      global_search_path(params)
    end
  end
  helper_method :search_path_for

  # Pre-compute town statistics for sidebar (only when town is present)
  # Cached for 5 minutes to reduce query load
  # Structure matches TownScoped concern to avoid cache key collisions
  def town_stats
    return {} unless @current_town

    @town_stats ||= Rails.cache.fetch("town_stats/#{@current_town.id}", expires_in: 5.minutes) do
      {
        documents_count: @current_town.documents.count,
        governing_bodies_count: @current_town.governing_bodies.count,
        people_count: @current_town.people.count,
        topics_count: Topic.for_town(@current_town).with_actions.count,
        complete_count: @current_town.documents.complete.count,
        processing_count: @current_town.documents.where(status: [ :extracting_text, :extracting_metadata ]).count
      }
    end
  end
  helper_method :town_stats
end
