# frozen_string_literal: true

# Shared concern for models that need name normalization.
# Provides consistent name normalization across Attendee, Person, and GoverningBody.
module NameNormalizable
  extend ActiveSupport::Concern

  included do
    before_validation :set_normalized_name, if: -> { name.present? && (normalized_name.blank? || name_changed?) }
  end

  class_methods do
    # Normalize a name for matching purposes
    # @param name [String] the name to normalize
    # @param strip_titles [Boolean] whether to strip titles like Mr., Dr., Jr., etc.
    # @return [String] the normalized name
    def normalize_name(name, strip_titles: strip_titles_on_normalize?)
      normalized = name.to_s.downcase.squish
      return normalized unless strip_titles

      normalized
        .gsub(/\b(mr|mrs|ms|dr|jr|sr|ii|iii|iv)\.?\b/i, "")
        .gsub(/[-]/, " ")  # Convert hyphens to spaces
        .gsub(/[^a-z\s]/i, "")  # Remove non-alpha except spaces
        .squish
    end

    # Override in models that need title stripping (Attendee, Person)
    def strip_titles_on_normalize?
      false
    end
  end

  private

  def set_normalized_name
    self.normalized_name = self.class.normalize_name(name)
  end
end
