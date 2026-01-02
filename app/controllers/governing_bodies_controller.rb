# frozen_string_literal: true

class GoverningBodiesController < ApplicationController
  include TownScoped
  include MeetingTimeline

  def index
    # Use JOIN with GROUP BY instead of correlated subquery for people_count
    @governing_bodies = current_town.governing_bodies
      .left_joins(:attendees)
      .select("governing_bodies.*, COUNT(DISTINCT attendees.person_id) AS people_count")
      .group("governing_bodies.id")
      .by_document_count
  end

  def show
    # Use JOIN with GROUP BY instead of correlated subquery for people_count
    @governing_body = current_town.governing_bodies
      .left_joins(:attendees)
      .select("governing_bodies.*, COUNT(DISTINCT attendees.person_id) AS people_count")
      .group("governing_bodies.id")
      .find(params[:id])

    # Build hierarchical timeline: year → month → day → meetings
    # Eager load pdf attachment and topics to avoid N+1 queries
    @meetings_by_year = build_meetings_hierarchy(
      @governing_body.documents.complete.includes(:topics).with_attached_pdf
    )

    @pagy_people, @people = pagy(
      @governing_body.people.by_appearances,
      limit: 24,
      page_param: :people_page
    )
  end
end
