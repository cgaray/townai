# frozen_string_literal: true

# Unmerges an Attendee from its Person by creating a new Person for it.
# This reverses a previous merge operation.
class PersonUnmerger
  attr_reader :attendee, :new_person, :errors

  def initialize(attendee:)
    @attendee = attendee
    @errors = []
    @new_person = nil
  end

  # Perform the unmerge operation
  # Returns true on success, false on failure (check errors for details)
  def unmerge!
    validate_unmerge!
    return false if errors.any?

    old_person = attendee.person

    ActiveRecord::Base.transaction do
      # Create a new Person for this attendee
      @new_person = Person.create!(
        name: attendee.name,
        normalized_name: attendee.normalized_name,
        town: old_person.town
      )

      # Move attendee to new person
      attendee.update!(person: @new_person)

      # Update counter caches for both people
      old_person.update_appearances_count!
      @new_person.update_appearances_count!
    end

    true
  rescue StandardError => e
    errors << "Unmerge failed: #{e.message}"
    false
  end

  private

  def validate_unmerge!
    errors << "Attendee not found" if attendee.nil?
    errors << "Attendee has no person" if attendee&.person.nil?

    if attendee&.person&.attendees&.count == 1
      errors << "Cannot unmerge: this is the only identity for this person"
    end
  end
end
