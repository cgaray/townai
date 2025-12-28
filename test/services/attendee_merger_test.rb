require "test_helper"

class AttendeeMergerTest < ActiveSupport::TestCase
  setup do
    @source = attendees(:jon_smith_finance)
    @target = attendees(:john_smith_finance)
    @document = documents(:complete_agenda)

    # Clean up any existing document_attendees to avoid uniqueness conflicts
    DocumentAttendee.where(document: @document).delete_all

    # Create a document link for source attendee
    DocumentAttendee.create!(
      document: @document,
      attendee: @source,
      role: "member",
      status: "present"
    )
  end

  test "merge moves document_attendees from source to target" do
    merger = AttendeeMerger.new(source: @source, target: @target)

    assert_difference -> { @source.reload.document_attendees.count }, -1 do
      assert merger.merge!
    end

    # Document should now be linked to target
    assert DocumentAttendee.exists?(document: @document, attendee: @target)
    assert_not DocumentAttendee.exists?(document: @document, attendee: @source)
  end

  test "merge marks source as merged" do
    merger = AttendeeMerger.new(source: @source, target: @target)
    merger.merge!

    @source.reload
    assert @source.merged?
    assert_equal @target, @source.merged_into
  end

  test "merge combines governing_bodies" do
    @source.update!(governing_bodies: [ "Finance Committee", "Special Committee" ])
    @target.update!(governing_bodies: [ "Finance Committee" ])

    merger = AttendeeMerger.new(source: @source, target: @target)
    merger.merge!

    @target.reload
    assert_includes @target.governing_bodies, "Finance Committee"
    assert_includes @target.governing_bodies, "Special Committee"
  end

  test "merge fails when source is nil" do
    merger = AttendeeMerger.new(source: nil, target: @target)

    assert_not merger.merge!
    assert_includes merger.errors, "Source attendee not found"
  end

  test "merge fails when target is nil" do
    merger = AttendeeMerger.new(source: @source, target: nil)

    assert_not merger.merge!
    assert_includes merger.errors, "Target attendee not found"
  end

  test "merge fails when source equals target" do
    merger = AttendeeMerger.new(source: @source, target: @source)

    assert_not merger.merge!
    assert_includes merger.errors, "Cannot merge an attendee into itself"
  end

  test "merge fails when source is already merged" do
    merged = attendees(:merged_attendee)
    merger = AttendeeMerger.new(source: merged, target: @target)

    assert_not merger.merge!
    assert_includes merger.errors, "Source attendee is already merged"
  end

  test "merge fails when target is already merged" do
    merged = attendees(:merged_attendee)
    merger = AttendeeMerger.new(source: @source, target: merged)

    assert_not merger.merge!
    assert_includes merger.errors, "Target attendee is already merged"
  end

  test "merge handles duplicate document links" do
    # Create link for target to same document
    DocumentAttendee.create!(
      document: @document,
      attendee: @target,
      role: "chair",
      status: "present"
    )

    merger = AttendeeMerger.new(source: @source, target: @target)

    # Should not raise error, source link should be deleted
    assert merger.merge!
    assert_not DocumentAttendee.exists?(document: @document, attendee: @source)
  end
end
