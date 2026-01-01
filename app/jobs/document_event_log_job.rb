class DocumentEventLogJob < ApplicationJob
  queue_as :default

  def perform(document_id:, event_type:, metadata: nil)
    DocumentEventLog.create!(
      document_id: document_id,
      event_type: event_type,
      metadata: metadata&.to_json
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create document event log: #{e.message}"
  end
end
