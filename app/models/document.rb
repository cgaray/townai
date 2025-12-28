class Document < ApplicationRecord
  has_one_attached :pdf

  enum :status, [ :pending, :extracting_text, :extracting_metadata, :complete, :failed ]
end
