# frozen_string_literal: true

class GoverningBodiesController < ApplicationController
  include MeetingTimeline

  def index
    @governing_bodies = GoverningBody
      .by_document_count
      .select("governing_bodies.*, (SELECT COUNT(DISTINCT person_id) FROM attendees WHERE attendees.governing_body_id = governing_bodies.id) AS people_count")
  end

  def show
    @governing_body = GoverningBody
      .select("governing_bodies.*, (SELECT COUNT(DISTINCT person_id) FROM attendees WHERE attendees.governing_body_id = governing_bodies.id) AS people_count")
      .find(params[:id])

    # Build hierarchical timeline: year → month → day → documents
    @meetings_by_year = build_meetings_hierarchy(@governing_body.documents.complete)

    @pagy_people, @people = pagy(
      @governing_body.people.by_appearances,
      limit: 24,
      page_param: :people_page
    )
  end
end
