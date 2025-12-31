class DocumentsController < ApplicationController
  # SQL fragment for sorting: complete first, then failed, then pending/processing
  # Enum values: pending=0, extracting_text=1, extracting_metadata=2, complete=3, failed=4
  STATUS_SORT_SQL = "CASE status WHEN 3 THEN 0 WHEN 4 THEN 1 ELSE 2 END".freeze

  def index
    @status_counts = Document.group(:status).count
    # Show complete documents first, then failed, then pending
    # Eager load pdf attachment to avoid N+1 queries
    documents = Document.with_attached_pdf.order(Arel.sql(STATUS_SORT_SQL), created_at: :desc)
    @pagy, @documents = pagy(documents, limit: 24)
  end

  def show
    # Eager load document_attendees with their attendees and people to avoid N+1
    @document = Document
      .includes(document_attendees: { attendee: :person })
      .with_attached_pdf
      .find(params[:id])
  end

  def retry
    @document = Document.find(params[:id])

    if @document.failed?
      @document.update!(status: :pending, extracted_metadata: nil)
      ExtractMetadataJob.perform_later(@document.id)
      redirect_to @document, notice: "Document queued for re-extraction."
    else
      redirect_to @document, alert: "Only failed documents can be retried."
    end
  end
end
