# frozen_string_literal: true

module Admin
  class DocumentsController < BaseController
    before_action :set_document, only: %i[show update destroy reextract approve reject]

    def index
      # Status counts for pipeline display
      @status_counts = Document.group(:status).count

      # Build base query
      @documents = Document
                     .includes(:governing_body)
                     .with_attached_pdf
                     .order(created_at: :desc)

      # Filter by stage (maps to status)
      case params[:stage]
      when "pending"
        @documents = @documents.pending
      when "extracting"
        @documents = @documents.where(status: [ :extracting_text, :extracting_metadata ])
      when "pending_review"
        @documents = @documents.pending_review
      when "complete"
        @documents = @documents.complete
      when "failed"
        @documents = @documents.failed
      when "rejected"
        @documents = @documents.rejected
      end

      # Filter by governing body
      if params[:governing_body_id].present?
        @documents = @documents.where(governing_body_id: params[:governing_body_id])
      end

      # Filter by confidence (only for pending_review)
      if params[:confidence].present? && params[:stage] == "pending_review"
        @documents = @documents.where(extraction_confidence: params[:confidence])
      end

      @pagy, @documents = pagy(@documents, limit: 50)

      # For filter dropdowns
      @governing_bodies = GoverningBody.joins(:documents).distinct.order(:name)
    end

    def show
      @topics = @document.topics.ordered
      @attendees = @document.document_attendees.includes(:attendee)
      @governing_bodies = GoverningBody.includes(:town).order(:name)
    end

    def create
      town = Town.find(params[:town_id]) if params[:town_id].present?

      uploaded_files = params[:files] || []
      if uploaded_files.empty?
        redirect_to admin_documents_path, alert: "Please select at least one PDF file."
        return
      end

      results = { created: 0, duplicates: 0, errors: [] }

      uploaded_files.each do |file|
        next unless file.respond_to?(:read)

        # Check for duplicates using file hash
        file_hash = Digest::SHA256.hexdigest(file.read)
        file.rewind

        if Document.exists?(source_file_hash: file_hash)
          results[:duplicates] += 1
          next
        end

        begin
          doc = Document.create!(
            pdf: file,
            source_file_name: file.original_filename,
            source_file_hash: file_hash,
            status: :pending
          )

          # Queue extraction job
          ExtractMetadataJob.perform_later(doc.id, town&.id)
          results[:created] += 1
        rescue StandardError => e
          results[:errors] << "#{file.original_filename}: #{e.message}"
        end
      end

      AuditLogJob.perform_later(
        user: current_user,
        action: "document_bulk_upload",
        resource_type: "Document",
        new_state: results.to_json,
        ip_address: request.remote_ip
      )

      message = "Uploaded #{results[:created]} document(s)."
      message += " #{results[:duplicates]} duplicate(s) skipped." if results[:duplicates] > 0
      message += " #{results[:errors].length} error(s)." if results[:errors].any?

      redirect_to admin_documents_path(stage: "pending"), notice: message
    end

    def update
      previous_state = {
        governing_body_id: @document.governing_body_id,
        extracted_metadata: @document.extracted_metadata
      }

      # Update governing body if changed
      if params[:document].present? && params[:document][:governing_body_id].present?
        @document.governing_body_id = params[:document][:governing_body_id]
      end

      # Update metadata fields if provided
      if params[:metadata].present?
        metadata = @document.parsed_metadata
        metadata["document_type"] = params[:metadata][:document_type] if params[:metadata][:document_type].present?
        metadata["meeting_date"] = params[:metadata][:meeting_date] if params[:metadata][:meeting_date].present?
        metadata["governing_body"] = params[:metadata][:governing_body] if params[:metadata][:governing_body].present?
        @document.extracted_metadata = metadata.to_json
      end

      if @document.save
        AuditLogJob.perform_later(
          user: current_user,
          action: "document_update",
          resource_type: "Document",
          resource_id: @document.id,
          previous_state: previous_state.to_json,
          new_state: { governing_body_id: @document.governing_body_id }.to_json,
          ip_address: request.remote_ip
        )

        redirect_to admin_documents_path(stage: "pending_review"), notice: "Document updated."
      else
        @governing_bodies = GoverningBody.includes(:town).order(:name)
        render :show, status: :unprocessable_entity
      end
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
      @document.update!(status: :pending, extracted_metadata: nil, extraction_confidence: nil)

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

    def approve
      previous_status = @document.status
      @document.approve!(current_user)

      AuditLogJob.perform_later(
        user: current_user,
        action: "document_approve",
        resource_type: "Document",
        resource_id: @document.id,
        previous_state: { status: previous_status }.to_json,
        new_state: { status: "complete" }.to_json,
        ip_address: request.remote_ip
      )

      redirect_back fallback_location: admin_documents_path(stage: "pending_review"),
                    notice: "Document approved."
    end

    def reject
      previous_status = @document.status
      @document.reject!(current_user, reason: params[:reason])

      AuditLogJob.perform_later(
        user: current_user,
        action: "document_reject",
        resource_type: "Document",
        resource_id: @document.id,
        previous_state: { status: previous_status }.to_json,
        new_state: { status: "rejected", reason: params[:reason] }.to_json,
        ip_address: request.remote_ip
      )

      redirect_back fallback_location: admin_documents_path(stage: "pending_review"),
                    notice: "Document rejected."
    end

    def bulk_approve
      scope = Document.needs_review

      # Filter by governing body if specified
      if params[:governing_body_id].present?
        scope = scope.where(governing_body_id: params[:governing_body_id])
      end

      # Filter by confidence if specified
      if params[:confidence].present?
        scope = scope.where(extraction_confidence: params[:confidence])
      end

      # Filter by specific IDs if provided (for checkbox selection)
      if params[:document_ids].present?
        scope = scope.where(id: params[:document_ids])
      end

      count = 0
      scope.find_each do |doc|
        doc.approve!(current_user)
        count += 1
      end

      AuditLogJob.perform_later(
        user: current_user,
        action: "document_bulk_approve",
        resource_type: "Document",
        new_state: {
          approved_count: count,
          governing_body_id: params[:governing_body_id],
          confidence: params[:confidence]
        }.to_json,
        ip_address: request.remote_ip
      )

      redirect_to admin_documents_path(stage: "pending_review"),
                  notice: "#{count} document(s) approved."
    end

    def bulk_retry
      governing_body = GoverningBody.find(params[:governing_body_id])
      failed_documents = governing_body.documents.failed

      if failed_documents.empty?
        redirect_to admin_documents_path(stage: "failed", governing_body_id: governing_body.id),
                    alert: "No failed documents to retry."
        return
      end

      count = 0
      failed_documents.find_each do |doc|
        doc.update!(status: :pending, extracted_metadata: nil, extraction_confidence: nil)
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

      redirect_to admin_documents_path(stage: "pending"),
                  notice: "#{count} documents queued for re-extraction."
    end

    private

    def set_document
      @document = Document.find(params[:id])
    end
  end
end
