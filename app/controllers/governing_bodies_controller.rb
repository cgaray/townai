# frozen_string_literal: true

class GoverningBodiesController < ApplicationController
  include TownScoped
  include MeetingTimeline

  def index
    @governing_bodies = current_town.governing_bodies
      .by_document_count
      .select("governing_bodies.*, (SELECT COUNT(DISTINCT person_id) FROM attendees WHERE attendees.governing_body_id = governing_bodies.id) AS people_count")
  end

  def show
    @governing_body = current_town.governing_bodies
      .select("governing_bodies.*, (SELECT COUNT(DISTINCT person_id) FROM attendees WHERE attendees.governing_body_id = governing_bodies.id) AS people_count")
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
