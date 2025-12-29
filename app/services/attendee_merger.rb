# frozen_string_literal: true

# Merges duplicate attendee records into a single canonical record.
# Source attendee's document links are moved to target, and source is marked as merged.
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
      move_document_attendees
      update_target_governing_bodies
      mark_source_as_merged
      update_target_dates_and_counts
    end

    true
  rescue StandardError => e
    errors << "Merge failed: #{e.message}"
    false
  end

  private

  def validate_merge!
    errors << "Source attendee not found" if source.nil?
    errors << "Target attendee not found" if target.nil?
    errors << "Cannot merge an attendee into itself" if source&.id == target&.id
    errors << "Source attendee is already merged" if source&.merged?
    errors << "Target attendee is already merged" if target&.merged?
  end

  def move_document_attendees
    # Move all document links from source to target
    # Use database-level query to avoid stale collection issues from concurrent merges
    # Loop until no more records to move (handles concurrent modifications)
    # Safety counter prevents infinite loops from unexpected edge cases
    max_iterations = DocumentAttendee.where(attendee_id: source.id).count + 10
    iterations = 0

    loop do
      iterations += 1
      if iterations > max_iterations
        raise "Merge loop exceeded maximum iterations (#{max_iterations}) - possible infinite loop"
      end

      da = DocumentAttendee.find_by(attendee_id: source.id)
      break unless da

      da.update!(attendee: target)
    rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
      # Target already has a link to this document - delete the duplicate
      da.destroy!
    end
  end

  def update_target_governing_bodies
    # Combine governing bodies from both attendees
    combined_bodies = (target.governing_bodies || []) | (source.governing_bodies || [])
    target.update!(governing_bodies: combined_bodies.uniq)
  end

  def mark_source_as_merged
    source.update!(merged_into: target, merged_at: Time.current)
  end

  def update_target_dates_and_counts
    # Update counter caches for both source and target
    Attendee.reset_counters(target.id, :document_attendees)
    Attendee.reset_counters(source.id, :document_attendees)

    # Update seen dates
    target.update_seen_dates!
  end
end
