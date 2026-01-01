# frozen_string_literal: true

# Computes potential duplicate people and stores them in DuplicateSuggestion.
# Runs nightly via Solid Queue, can also be triggered manually by admins.
#
# Uses two matching strategies:
# 1. Exact: Same normalized_name
# 2. Similar: Within Levenshtein distance threshold (percentage-based)
#
# Pairs are stored with smaller person_id first to avoid duplicates.
class ComputeDuplicatesJob < ApplicationJob
  queue_as :default

  # Default: 20% of name length, minimum 1
  SIMILARITY_PERCENT_DEFAULT = 20

  def perform
    Rails.logger.info "[ComputeDuplicatesJob] Starting duplicate computation"

    # Clear existing suggestions (full rebuild)
    DuplicateSuggestion.delete_all

    suggestions = []
    people = Person.order(:id).to_a

    people.each do |person|
      # Find exact matches (same normalized_name, higher ID)
      exact_matches = people.select { |p| p.id > person.id && p.normalized_name == person.normalized_name }

      exact_matches.each do |match|
        suggestions << build_suggestion(person, match, "exact", 0)
      end

      # Find similar matches (within Levenshtein threshold)
      max_distance = max_distance_for(person.normalized_name)
      min_length = [ person.normalized_name.length - max_distance, 1 ].max
      max_length = person.normalized_name.length + max_distance

      candidates = people.select do |p|
        p.id > person.id &&
          p.normalized_name != person.normalized_name &&
          p.normalized_name.length.between?(min_length, max_length)
      end

      candidates.each do |candidate|
        distance = levenshtein_distance(person.normalized_name, candidate.normalized_name)
        if distance <= max_distance
          suggestions << build_suggestion(person, candidate, "similar", distance)
        end
      end
    end

    # Bulk insert
    DuplicateSuggestion.insert_all(suggestions) if suggestions.any?

    Rails.logger.info "[ComputeDuplicatesJob] Created #{suggestions.size} duplicate suggestions"
  end

  private

  def build_suggestion(person, duplicate, match_type, score)
    {
      person_id: person.id,
      duplicate_person_id: duplicate.id,
      match_type: match_type,
      similarity_score: score,
      created_at: Time.current,
      updated_at: Time.current
    }
  end

  def max_distance_for(name)
    percentage = similarity_percent / 100.0
    [ (name.length * percentage).floor, 1 ].max
  end

  def similarity_percent
    ENV.fetch("DUPLICATE_SIMILARITY_PERCENT", SIMILARITY_PERCENT_DEFAULT).to_i
  end

  def levenshtein_distance(s1, s2)
    Text::Levenshtein.distance(s1, s2)
  end
end
