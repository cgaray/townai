# frozen_string_literal: true

module Admin
  class DocumentsController < BaseController
    before_action :set_document, only: %i[destroy reextract]

    def index
      @documents = Document.includes(:governing_body)
                           .with_attached_pdf
                           .order(created_at: :desc)

      # Filter by status
      @documents = @documents.where(status: params[:status]) if params[:status].present?

      # Filter by governing body
      if params[:governing_body_id].present?
        @documents = @documents.where(governing_body_id: params[:governing_body_id])
      end

      @pagy, @documents = pagy(@documents, limit: 50)

      # For filter dropdowns
      @governing_bodies = GoverningBody.joins(:documents).distinct.order(:name)
      @status_counts = Document.group(:status).count
    end

    def destroy
      previous_state = {
        source_file_name: @document.source_file_name,
        governing_body_id: @document.governing_body_id,
        status: @document.status,
        topics_count: @document.topics.count,
        attendees_count: @document.document_attendees.count
      }

      @document.destroy!

      AuditLogJob.perform_later(
        user: current_user,
        action: "document_delete",
        resource_type: "Document",
        resource_id: @document.id,
        previous_state: previous_state.to_json,
        ip_address: request.remote_ip
      )

      redirect_to admin_documents_path, notice: "Document deleted successfully."
    rescue ActiveRecord::RecordNotDestroyed => e
      redirect_to admin_documents_path, alert: "Failed to delete document: #{e.message}"
    end

    def reextract
      previous_state = {
        status: @document.status,
        had_metadata: @document.extracted_metadata.present?
      }

      # Clear existing data and reset status
      @document.topics.destroy_all
      @document.document_attendees.destroy_all
      @document.update!(status: :pending, extracted_metadata: nil)

      ExtractMetadataJob.perform_later(@document.id, @document.governing_body&.town_id)

      AuditLogJob.perform_later(
        user: current_user,
        action: "document_reextract",
        resource_type: "Document",
        resource_id: @document.id,
        previous_state: previous_state.to_json,
        new_state: { status: "pending" }.to_json,
        ip_address: request.remote_ip
      )

      redirect_back fallback_location: admin_documents_path,
                    notice: "Document queued for re-extraction."
    end

    def bulk_retry
      governing_body = GoverningBody.find(params[:governing_body_id])
      failed_documents = governing_body.documents.failed

      if failed_documents.empty?
        redirect_to admin_documents_path(governing_body_id: governing_body.id),
                    alert: "No failed documents to retry."
        return
      end

      count = 0
      failed_documents.find_each do |doc|
        doc.update!(status: :pending, extracted_metadata: nil)
        ExtractMetadataJob.perform_later(doc.id, governing_body.town_id)
        count += 1
      end

      AuditLogJob.perform_later(
        user: current_user,
        action: "document_bulk_retry",
        resource_type: "GoverningBody",
        resource_id: governing_body.id,
        new_state: { retried_count: count }.to_json,
        ip_address: request.remote_ip
      )

      redirect_to admin_documents_path(governing_body_id: governing_body.id),
                  notice: "#{count} documents queued for re-extraction."
    end

    private

    def set_document
      @document = Document.find(params[:id])
    end
  end
end
