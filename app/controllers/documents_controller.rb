class DocumentsController < ApplicationController
  def index
    @status_counts = Document.group(:status).count
    # Show complete documents first, then by creation date
    documents = Document.order(
      Arel.sql("CASE status WHEN #{Document.statuses[:complete]} THEN 0 WHEN #{Document.statuses[:failed]} THEN 1 ELSE 2 END"),
      created_at: :desc
    )
    @pagy, @documents = pagy(documents, limit: 24)
  end

  def show
    @document = Document.find(params[:id])
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
