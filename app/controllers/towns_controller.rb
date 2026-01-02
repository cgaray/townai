# frozen_string_literal: true

class TownsController < ApplicationController
  def index
    @towns = Town.alphabetical.includes(:governing_bodies)
  end

  def show
    @town = Town.find_by!(slug: params[:slug])
    @recent_documents = @town.documents.complete.order(created_at: :desc).limit(5)

    # Use cached town stats to avoid 7+ COUNT queries
    # Structure matches TownScoped concern to avoid cache key collisions
    @town_stats = Rails.cache.fetch("town_stats/#{@town.id}", expires_in: 5.minutes) do
      {
        documents_count: @town.documents.count,
        governing_bodies_count: @town.governing_bodies.count,
        people_count: @town.people.count,
        topics_count: Topic.for_town(@town).with_actions.count,
        complete_count: @town.documents.complete.count,
        processing_count: @town.documents.where(status: [ :extracting_text, :extracting_metadata ]).count
      }
    end

    # Expose individual counts for view compatibility
    @governing_bodies_count = @town_stats[:governing_bodies_count]
    @people_count = @town_stats[:people_count]
    @documents_count = @town_stats[:documents_count]
  end

  private

  # Expose @town as current_town for layout sidebar
  def current_town
    @town
  end
  helper_method :current_town

  def town_stats
    @town_stats || {}
  end
  helper_method :town_stats
end
