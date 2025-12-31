# frozen_string_literal: true

# Concern for controllers that are scoped to a specific town
# Provides @current_town and helper methods for town-scoped resources
module TownScoped
  extend ActiveSupport::Concern

  included do
    before_action :set_current_town
    before_action :set_town_stats, if: -> { @current_town.present? }
    helper_method :current_town, :town_stats
  end

  private

  def set_current_town
    @current_town = Town.find_by!(slug: params[:town_slug])
  rescue ActiveRecord::RecordNotFound
    redirect_to towns_path, alert: "Town not found"
  end

  def current_town
    @current_town
  end

  # Pre-compute town statistics to avoid N+1 in layout
  def set_town_stats
    @town_stats = {
      documents_count: @current_town.documents.count,
      governing_bodies_count: @current_town.governing_bodies.count,
      people_count: @current_town.people.count,
      complete_count: @current_town.documents.complete.count,
      processing_count: @current_town.documents.where(status: [:extracting_text, :extracting_metadata]).count
    }
  end

  def town_stats
    @town_stats || {}
  end
end
