class Document < ApplicationRecord
  has_one_attached :pdf

  enum :status, [ :pending, :extracting_text, :extracting_metadata, :complete, :failed ]

  # app/models/document.rb
  def metadata_field(field)
    return nil unless extracted_metadata.present?
    JSON.parse(extracted_metadata)[field] rescue nil
  end
end
