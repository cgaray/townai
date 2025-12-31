# frozen_string_literal: true

class TownsController < ApplicationController
  def index
    @towns = Town.alphabetical.includes(:governing_bodies)
  end

  def show
    @town = Town.find_by!(slug: params[:slug])
    @recent_documents = @town.documents.complete.order(created_at: :desc).limit(5)
    @governing_bodies_count = @town.governing_bodies.count
    @people_count = @town.people.count
    @documents_count = @town.documents.count

    # Pre-compute stats for sidebar (same as TownScoped concern)
    @town_stats = {
      documents_count: @documents_count,
      governing_bodies_count: @governing_bodies_count,
      people_count: @people_count,
      complete_count: @town.documents.complete.count,
      processing_count: @town.documents.where(status: [ :extracting_text, :extracting_metadata ]).count
    }
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
