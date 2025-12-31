class Document < ApplicationRecord
  has_one_attached :pdf
  belongs_to :governing_body, optional: true, counter_cache: true
  has_many :api_calls, dependent: :nullify
  has_many :document_attendees, dependent: :destroy
  has_many :attendees, through: :document_attendees

  enum :status, [ :pending, :extracting_text, :extracting_metadata, :complete, :failed ]

  after_save :reindex_for_search, if: :should_reindex?
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

  private

  def should_reindex?
    complete? && (saved_change_to_status? || saved_change_to_extracted_metadata?)
  end

  def reindex_for_search
    ReindexSearchJob.perform_later("document", id)
  end

  def remove_from_search_index
    SearchIndexer.remove_document(id)
  end
end
