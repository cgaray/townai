class Document < ApplicationRecord
  has_one_attached :pdf
  has_many :api_calls, dependent: :nullify
  has_many :document_attendees, dependent: :destroy
  has_many :attendees, through: :document_attendees

  enum :status, [ :pending, :extracting_text, :extracting_metadata, :complete, :failed ]

  def metadata_field(field)
    return nil unless extracted_metadata.present?
    JSON.parse(extracted_metadata)[field] rescue nil
  end
end
