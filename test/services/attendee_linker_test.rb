require "test_helper"

class AttendeeLinkerTest < ActiveSupport::TestCase
  setup do
    @complete_doc = documents(:complete_agenda)
    # Clean up any existing document_attendees for this document
    DocumentAttendee.where(document: @complete_doc).delete_all
  end

  test "link_attendees creates new attendees from document metadata" do
    # Clear existing attendees for clean test
    DocumentAttendee.delete_all
    Attendee.delete_all

    linker = AttendeeLinker.new(@complete_doc)

    assert_difference "Attendee.count", 2 do
      assert_difference "DocumentAttendee.count", 2 do
        assert linker.link_attendees
      end
    end

    assert_equal 2, linker.created_count
    assert_equal 0, linker.linked_count
  end

  test "link_attendees links to existing attendees" do
    # Create a fresh complete document with known metadata
    doc = Document.create!(
      source_file_name: "test_link_existing.pdf",
      source_file_hash: "unique_for_link_test_#{SecureRandom.hex(8)}",
      status: :complete,
      extracted_metadata: {
        governing_body: "Test Board",
        attendees: [
          { name: "Alice Test", role: "chair", status: "present" },
          { name: "Bob Test", role: "member", status: "present" }
        ]
      }.to_json
    )

    # First run creates attendees
    linker1 = AttendeeLinker.new(doc)
    assert linker1.link_attendees, "First link should succeed"
    assert_equal 2, linker1.created_count

    # Clear document links but keep attendees - use delete_all on the relation
    # and reload to clear association cache
    DocumentAttendee.where(document_id: doc.id).delete_all
    doc.reload

    # Second run should link to existing
    linker2 = AttendeeLinker.new(doc)

    assert_no_difference "Attendee.count" do
      assert_difference "DocumentAttendee.count", 2 do
        assert linker2.link_attendees, "Second link should succeed"
      end
    end

    assert_equal 0, linker2.created_count
    assert_equal 2, linker2.linked_count
  end

  test "link_attendees returns false for non-complete documents" do
    pending_doc = documents(:pending_document)
    linker = AttendeeLinker.new(pending_doc)

    assert_not linker.link_attendees
  end

  test "link_attendees clears existing links on re-run" do
    linker = AttendeeLinker.new(@complete_doc)
    linker.link_attendees

    original_count = @complete_doc.document_attendees.count
    assert_equal 2, original_count

    # Re-running should replace links, not duplicate
    linker2 = AttendeeLinker.new(@complete_doc)
    linker2.link_attendees

    @complete_doc.reload
    assert_equal 2, @complete_doc.document_attendees.count
  end

  test "link_attendees stores role and status" do
    DocumentAttendee.delete_all
    Attendee.delete_all

    linker = AttendeeLinker.new(@complete_doc)
    linker.link_attendees

    # John Smith is chair, present
    john = Attendee.find_by(normalized_name: "john smith")
    da = DocumentAttendee.find_by(attendee: john, document: @complete_doc)

    assert_equal "chair", da.role
    assert_equal "present", da.status
  end

  test "link_attendees returns false when governing_body is missing" do
    doc = Document.new(
      source_file_name: "test.pdf",
      source_file_hash: "unique123",
      status: :complete,
      extracted_metadata: '{"attendees":[{"name":"Test Person"}]}'
    )
    doc.save!

    linker = AttendeeLinker.new(doc)
    assert_not linker.link_attendees
  end

  test "link_attendees skips attendees with blank names" do
    doc = Document.create!(
      source_file_name: "test.pdf",
      source_file_hash: "unique456",
      status: :complete,
      extracted_metadata: '{"governing_body":"Test Board","attendees":[{"name":""},{"name":"Valid Person"}]}'
    )
    doc.save!

    linker = AttendeeLinker.new(doc)

    assert_difference "Attendee.count", 1 do
      linker.link_attendees
    end
  end

  test "link_attendees populates errors when document not complete" do
    pending_doc = documents(:pending_document)
    linker = AttendeeLinker.new(pending_doc)

    assert_not linker.link_attendees
    assert_not linker.success?
    assert linker.errors.any? { |e| e.include?("not complete") }
  end

  test "link_attendees populates errors when governing_body missing" do
    doc = Document.create!(
      source_file_name: "test_no_body.pdf",
      source_file_hash: "unique_no_body_#{SecureRandom.hex(8)}",
      status: :complete,
      extracted_metadata: '{"attendees":[{"name":"Test Person"}]}'
    )

    linker = AttendeeLinker.new(doc)

    assert_not linker.link_attendees
    assert_not linker.success?
    assert linker.errors.any? { |e| e.include?("governing_body") }
  end

  test "success? returns true when no errors" do
    linker = AttendeeLinker.new(@complete_doc)
    linker.link_attendees

    assert linker.success?
    assert_empty linker.errors
  end
end
