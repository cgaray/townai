require "test_helper"

class PersonMergerTest < ActiveSupport::TestCase
  setup do
    @source_person = people(:jon_smith)
    @target_person = people(:john_smith)
    @document = documents(:complete_agenda)

    # Clean up any existing document_attendees to avoid uniqueness conflicts
    DocumentAttendee.where(document: @document).delete_all
  end

  test "merge moves attendees from source to target" do
    source_attendee = attendees(:jon_smith_finance)
    original_target_count = @target_person.attendees.count

    merger = PersonMerger.new(source: @source_person, target: @target_person)
    assert merger.merge!

    source_attendee.reload
    @target_person.reload

    assert_equal @target_person, source_attendee.person
    assert_equal original_target_count + 1, @target_person.attendees.count
  end

  test "merge deletes source person" do
    source_id = @source_person.id

    merger = PersonMerger.new(source: @source_person, target: @target_person)
    merger.merge!

    assert_nil Person.find_by(id: source_id)
  end

  test "merge updates target counter cache" do
    # Create a document link for source attendee
    source_attendee = attendees(:jon_smith_finance)
    DocumentAttendee.create!(
      document: @document,
      attendee: source_attendee,
      role: "member",
      status: "present"
    )
    @source_person.update_appearances_count!
    @target_person.update_appearances_count!

    original_source_count = @source_person.document_appearances_count
    original_target_count = @target_person.document_appearances_count

    merger = PersonMerger.new(source: @source_person, target: @target_person)
    merger.merge!

    @target_person.reload
    # Target should now have source's document appearances added
    assert_equal original_target_count + original_source_count, @target_person.document_appearances_count
  end

  test "merge fails when source is nil" do
    merger = PersonMerger.new(source: nil, target: @target_person)

    assert_not merger.merge!
    assert_includes merger.errors, "Source person not found"
  end

  test "merge fails when target is nil" do
    merger = PersonMerger.new(source: @source_person, target: nil)

    assert_not merger.merge!
    assert_includes merger.errors, "Target person not found"
  end

  test "merge fails when source equals target" do
    merger = PersonMerger.new(source: @source_person, target: @source_person)

    assert_not merger.merge!
    assert_includes merger.errors, "Cannot merge a person into themselves"
  end
end
