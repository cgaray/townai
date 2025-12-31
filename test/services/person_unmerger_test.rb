require "test_helper"

class PersonUnmergerTest < ActiveSupport::TestCase
  setup do
    @person = people(:john_smith)
    @attendee = attendees(:john_smith_finance)
    @second_attendee = attendees(:j_smith_finance)

    # Merge the second attendee into the same person
    @second_attendee.update!(person: @person)
  end

  test "unmerge creates new person for attendee" do
    original_person_count = Person.count

    unmerger = PersonUnmerger.new(attendee: @second_attendee)
    assert unmerger.unmerge!

    assert_equal original_person_count + 1, Person.count
  end

  test "unmerge moves attendee to new person" do
    unmerger = PersonUnmerger.new(attendee: @second_attendee)
    unmerger.unmerge!

    @second_attendee.reload
    assert_not_equal @person, @second_attendee.person
    assert_equal @second_attendee.name, @second_attendee.person.name
  end

  test "unmerge returns new person via accessor" do
    unmerger = PersonUnmerger.new(attendee: @second_attendee)
    unmerger.unmerge!

    assert_not_nil unmerger.new_person
    assert_equal @second_attendee.reload.person, unmerger.new_person
  end

  test "unmerge updates counter caches" do
    # Create document links to verify counter cache updates
    doc = documents(:complete_agenda)
    DocumentAttendee.where(document: doc).delete_all

    DocumentAttendee.create!(document: doc, attendee: @second_attendee, role: "member")
    @person.update_appearances_count!

    original_count = @person.document_appearances_count

    unmerger = PersonUnmerger.new(attendee: @second_attendee)
    unmerger.unmerge!

    @person.reload
    assert_equal original_count - 1, @person.document_appearances_count
    assert_equal 1, unmerger.new_person.document_appearances_count
  end

  test "unmerge fails when person has only one attendee" do
    # Reset to single attendee
    @second_attendee.update!(person: people(:j_smith))

    unmerger = PersonUnmerger.new(attendee: @attendee)

    assert_not unmerger.unmerge!
    assert_includes unmerger.errors, "Cannot unmerge: this is the only identity for this person"
  end

  test "unmerge fails when attendee is nil" do
    unmerger = PersonUnmerger.new(attendee: nil)

    assert_not unmerger.unmerge!
    assert_includes unmerger.errors, "Attendee not found"
  end

  test "unmerge fails when attendee has no person" do
    # This shouldn't happen in practice, but test defensive coding
    orphan_attendee = Attendee.new(
      name: "Orphan",
      normalized_name: "orphan",
      governing_body_extracted: "Test Board"
    )
    # Don't save - just test the validation
    unmerger = PersonUnmerger.new(attendee: orphan_attendee)

    assert_not unmerger.unmerge!
    assert_includes unmerger.errors, "Attendee has no person"
  end
end
