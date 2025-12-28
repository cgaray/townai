class DocumentsController < ApplicationController
  def index
    @status_counts = Document.group(:status).count
    @documents = Document.order(created_at: :desc).limit(100)
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
