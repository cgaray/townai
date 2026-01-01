class DocumentEventLog < ApplicationRecord
  belongs_to :document

  validates :document, :event_type, presence: true

  EVENT_TYPES = %w[
    uploaded
    extraction_started
    extraction_failed
    extraction_completed
    metadata_extracted
    retry
    status_changed
    deleted
  ].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :by_document, ->(document) { where(document: document) }
  scope :by_event_type, ->(type) { where(event_type: type) }
  scope :failed, -> { where(event_type: "extraction_failed") }
  scope :successful, -> { where(event_type: "extraction_completed") }

  def metadata_parsed
    JSON.parse(metadata) if metadata.present?
  end

  def success?
    event_type == "extraction_completed"
  end

  def failure?
    event_type == "extraction_failed"
  end
end
