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

  private

  def should_reindex?
    complete? && (saved_change_to_status? || saved_change_to_extracted_metadata?)
  end

  def reindex_for_search
    SearchIndexer.index_document(self)
  end

  def remove_from_search_index
    SearchIndexer.remove_document(id)
  end
end
