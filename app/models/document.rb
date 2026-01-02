class Document < ApplicationRecord
  has_one_attached :pdf
  belongs_to :governing_body, optional: true, counter_cache: true
  belongs_to :reviewed_by, class_name: "User", optional: true
  has_many :api_calls, dependent: :nullify
  has_many :document_attendees, dependent: :destroy
  has_many :attendees, through: :document_attendees
  has_many :topics, dependent: :destroy

  enum :status, [ :pending, :extracting_text, :extracting_metadata, :complete, :failed, :pending_review, :rejected ]
  enum :extraction_confidence, { high: "high", medium: "medium", low: "low" }, prefix: true

  scope :needs_review, -> { where(status: :pending_review) }
  scope :approved, -> { where(status: :complete) }

  after_save :reindex_for_search, if: :should_reindex?
  before_destroy :cache_topic_ids_for_cleanup
  after_destroy :remove_from_search_index

  def parsed_metadata
    return {} unless extracted_metadata.present?

    if @parsed_metadata_source != extracted_metadata
      @parsed_metadata = JSON.parse(extracted_metadata) rescue {}
      @parsed_metadata_source = extracted_metadata
    end

    @parsed_metadata
  end

  def metadata_field(field)
    parsed_metadata[field]
  end

  def display_title
    # Try to build a meaningful title from metadata, fallback to source file name
    doc_type = metadata_field("document_type")&.titleize
    body = governing_body&.name || metadata_field("governing_body")
    date = meeting_date_formatted

    if body && date
      "#{body} #{doc_type || 'Document'} - #{date}"
    elsif body
      "#{body} #{doc_type || 'Document'}"
    else
      source_file_name
    end
  end

  def meeting_date_formatted
    date_str = metadata_field("meeting_date")
    return nil unless date_str.present?
    Date.parse(date_str).strftime("%B %d, %Y")
  rescue ArgumentError, TypeError
    date_str
  end

  # Calculate extraction confidence based on metadata completeness
  def self.calculate_confidence(metadata)
    return "low" unless metadata.is_a?(Hash)

    score = 0
    score += 1 if metadata["document_type"].present?
    score += 1 if metadata["governing_body"].present?
    score += 1 if metadata["meeting_date"].present?
    score += 1 if metadata["attendees"].is_a?(Array) && metadata["attendees"].any?
    score += 1 if metadata["topics"].is_a?(Array) && metadata["topics"].any?

    case score
    when 5 then "high"
    when 3..4 then "medium"
    else "low"
    end
  end

  # Approve document for public visibility
  def approve!(reviewer)
    update!(
      status: :complete,
      reviewed_at: Time.current,
      reviewed_by: reviewer,
      rejection_reason: nil
    )
  end

  # Reject document with reason
  def reject!(reviewer, reason: nil)
    was_complete = complete?
    update!(
      status: :rejected,
      reviewed_at: Time.current,
      reviewed_by: reviewer,
      rejection_reason: reason
    )
    # Remove from search index if it was previously indexed
    SearchIndexer.remove_document(id, topic_ids: topics.pluck(:id)) if was_complete
  end

  private

  def should_reindex?
    complete? && (saved_change_to_status? || saved_change_to_extracted_metadata?)
  end

  def reindex_for_search
    ReindexSearchJob.perform_later("document", id)
  end

  # Cache topic IDs before destroy so we can clean up search entries
  # (topics are destroyed first due to dependent: :destroy)
  def cache_topic_ids_for_cleanup
    @topic_ids_for_cleanup = topics.pluck(:id)
  end

  def remove_from_search_index
    SearchIndexer.remove_document(id, topic_ids: @topic_ids_for_cleanup || [])
  end
end
