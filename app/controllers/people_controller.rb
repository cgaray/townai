# frozen_string_literal: true

class PeopleController < ApplicationController
  def index
    @people = Person.by_appearances.limit(100)
  end

  def show
    @person = Person.find(params[:id])
    @attendees = @person.attendees.order(:name)
    @document_attendees = @person.document_attendees
                                  .includes(:attendee, document: :pdf_attachment)
                                  .order("documents.created_at DESC")
    @co_people = @person.co_people(limit: 10)
    @potential_duplicates = @person.potential_duplicates
  end
end
