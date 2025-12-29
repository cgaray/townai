# frozen_string_literal: true

# Merges two Person records by moving all attendees from source to target.
# The source Person is deleted after the merge.
# This is reversible via PersonUnmerger.
class AttendeeMerger
  attr_reader :source, :target, :errors

  def initialize(source:, target:)
    @source = source
    @target = target
    @errors = []
  end

  # Perform the merge operation
  # Returns true on success, false on failure (check errors for details)
  def merge!
    validate_merge!
    return false if errors.any?

    ActiveRecord::Base.transaction do
      # Move all attendees from source to target
      source.attendees.update_all(person_id: target.id)

      # Update counter cache on target
      target.update_appearances_count!

      # Delete the now-empty source person
      source.destroy!
    end

    true
  rescue StandardError => e
    errors << "Merge failed: #{e.message}"
    false
  end

  private

  def validate_merge!
    errors << "Source person not found" if source.nil?
    errors << "Target person not found" if target.nil?
    errors << "Cannot merge a person into themselves" if source&.id == target&.id
  end
end
