# frozen_string_literal: true

class SearchController < ApplicationController
  # GET /search - Full search results page
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

  # GET /search/quick - Quick results for modal (JSON)
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
end
