# frozen_string_literal: true

# Represents a raw attendee extraction from a document.
# Attendees are grouped under Person records for merging/unmerging.
# This model holds the immutable extraction data.
class Attendee < ApplicationRecord
  belongs_to :person
  belongs_to :governing_body, optional: true
  has_many :document_attendees, dependent: :destroy
  has_many :documents, through: :document_attendees

  validates :name, :normalized_name, :governing_body_extracted, presence: true
  validates :normalized_name, uniqueness: { scope: :governing_body_extracted }

  before_validation :set_normalized_name, if: -> { name.present? && normalized_name.blank? }

  # Normalize a name for matching purposes
  def self.normalize_name(name)
    name.to_s
        .downcase
        .gsub(/\b(mr|mrs|ms|dr|jr|sr|ii|iii|iv)\.?\b/i, "")
        .gsub(/[-]/, " ")  # Convert hyphens to spaces
        .gsub(/[^a-z\s]/i, "")  # Remove non-alpha except spaces
        .squish
  end

  # Calculate Levenshtein distance between two strings
  # Used for fuzzy name matching in duplicate detection
  def self.levenshtein_distance(s1, s2)
    m = s1.length
    n = s2.length
    return n if m.zero?
    return m if n.zero?

    d = Array.new(m + 1) { Array.new(n + 1, 0) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }

    (1..n).each do |j|
      (1..m).each do |i|
        cost = s1[i - 1] == s2[j - 1] ? 0 : 1
        d[i][j] = [ d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost ].min
      end
    end

    d[m][n]
  end

  private

  def set_normalized_name
    self.normalized_name = self.class.normalize_name(name)
  end
end
