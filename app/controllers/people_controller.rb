# frozen_string_literal: true

class PeopleController < ApplicationController
  include TownScoped
  include MeetingTimeline

  def index
    @pagy, @people = pagy(
      current_town.people
        .includes(attendees: :governing_body)
        .includes(:document_attendees)
        .by_appearances,
      limit: 24
    )
  end

  def show
    @person = current_town.people.find(params[:id])
    @attendees = @person.attendees.includes(:governing_body, :document_attendees).order(:name)
    @document_attendees = @person.document_attendees
                                  .includes(:attendee, document: [ :pdf_attachment, :topics ])
                                  .order("documents.created_at DESC")

    # Build extra data (role, status, topics) keyed by document_id for timeline
    extra_data = @document_attendees.each_with_object({}) do |da, hash|
      hash[da.document_id] = {
        role: da.role,
        status: da.status,
        source_text: da.source_text,
        topics: da.document.topics.ordered
      }
    end

    # Build hierarchical timeline with extra data
    documents = @document_attendees.map(&:document).uniq
    @meetings_by_year = build_meetings_hierarchy(documents, extra_data)

    @co_people = @person.co_people(limit: 10)
    @potential_duplicates = @person.potential_duplicates
  end
end
