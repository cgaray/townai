class AttendeesController < ApplicationController
  def index
    @attendees = Attendee.active
                         .by_appearances
                         .includes(:document_attendees)
                         .limit(100)

    # Group by governing body for sidebar stats
    @governing_body_counts = Attendee.active.group(:primary_governing_body).count
    @total_attendees = Attendee.active.count
  end

  def show
    @attendee = Attendee.find(params[:id])

    # Redirect to canonical if this attendee was merged
    if @attendee.merged?
      redirect_to attendee_path(@attendee.canonical), notice: "Redirected to merged attendee profile"
      return
    end

    # Get documents with this attendee, ordered by meeting date (descending)
    # Sort in Ruby to remain database-agnostic (avoid SQLite json_extract)
    @document_attendees = @attendee.document_attendees
                                    .includes(document: [ :pdf_attachment ])
                                    .sort_by { |da| da.document.metadata_field("meeting_date") || "" }
                                    .reverse

    # Get potential duplicates
    @potential_duplicates = @attendee.potential_duplicates

    # Get co-attendees
    @co_attendees = @attendee.co_attendees(limit: 10)
  end
end
