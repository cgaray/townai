# frozen_string_literal: true

# Represents a raw attendee extraction from a document.
# Attendees are grouped under Person records for merging/unmerging.
# This model holds the immutable extraction data.
class Attendee < ApplicationRecord
  include NameNormalizable

  belongs_to :person
  belongs_to :governing_body, optional: true
  has_many :document_attendees, dependent: :destroy
  has_many :documents, through: :document_attendees

  validates :name, :normalized_name, :governing_body_extracted, presence: true
  validates :normalized_name, uniqueness: { scope: :governing_body_extracted }

  # Strip titles (Mr., Dr., Jr., etc.) when normalizing attendee names
  def self.strip_titles_on_normalize?
    true
  end

  # Calculate Levenshtein distance between two strings
  # Used for fuzzy name matching in duplicate detection
  def self.levenshtein_distance(s1, s2)
    Text::Levenshtein.distance(s1, s2)
  end
end
