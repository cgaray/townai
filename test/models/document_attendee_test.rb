require "test_helper"

class DocumentAttendeeTest < ActiveSupport::TestCase
  test "should require document" do
    doc_attendee = DocumentAttendee.new(attendee: attendees(:john_smith_finance), status: "present")
    assert_not doc_attendee.valid?
    assert_includes doc_attendee.errors[:document], "must exist"
  end

  test "should require attendee" do
    doc_attendee = DocumentAttendee.new(document: documents(:complete_agenda), status: "present")
    assert_not doc_attendee.valid?
    assert_includes doc_attendee.errors[:attendee], "must exist"
  end

  test "should validate uniqueness of document_id scoped to attendee_id" do
    doc = documents(:complete_minutes)
    attendee = attendees(:john_smith_finance)
    
    DocumentAttendee.create!(document: doc, attendee: attendee, status: "present")
    duplicate = DocumentAttendee.new(document: doc, attendee: attendee, status: "absent")
    
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:document_id], "has already been taken"
  end

  test "should validate status inclusion" do
    doc_attendee = DocumentAttendee.new(
      document: documents(:complete_agenda),
      attendee: attendees(:john_smith_finance),
      status: "invalid_status"
    )
    assert_not doc_attendee.valid?
    assert_includes doc_attendee.errors[:status], "is not included in the list"
  end

  test "should accept valid statuses" do
    attendee = attendees(:john_smith_finance)
    
    DocumentAttendee::STATUSES.each_with_index do |status, index|
      # Create a new document for each status to avoid uniqueness constraint
      doc = Document.create!(
        source_file_name: "test_#{status}_#{index}.pdf",
        source_file_hash: "hash_#{status}_#{index}",
        status: 0,
        governing_body: governing_bodies(:select_board)
      )
      doc_attendee = DocumentAttendee.new(document: doc, attendee: attendee, status: status, role: "member #{status}")
      assert doc_attendee.valid?, "Expected #{status} to be valid"
    end
  end

  test "should allow nil status" do
    doc = Document.create!(
      source_file_name: "test_nil_status.pdf",
      source_file_hash: "hash_nil_status",
      status: 0,
      governing_body: governing_bodies(:select_board)
    )
    doc_attendee = DocumentAttendee.new(
      document: doc,
      attendee: attendees(:john_smith_finance),
      status: nil,
      role: "member"
    )
    assert doc_attendee.valid?
  end

  test "should allow free-form role values" do
    attendee = attendees(:john_smith_finance)
    
    roles = [ "chair", "vice-chair", "associate member", "clerk", "member" ]
    roles.each_with_index do |role, index|
      # Create a new document for each role to avoid uniqueness constraint
      doc = Document.create!(
        source_file_name: "test_role_#{index}.pdf",
        source_file_hash: "hash_role_#{index}",
        status: 0,
        governing_body: governing_bodies(:select_board)
      )
      doc_attendee = DocumentAttendee.new(document: doc, attendee: attendee, status: "present", role: role)
      assert doc_attendee.valid?, "Expected role '#{role}' to be valid"
    end
  end

  test "belongs to document" do
    doc = Document.create!(
      source_file_name: "test_belongs_to.pdf",
      source_file_hash: "hash_belongs_to",
      status: 0,
      governing_body: governing_bodies(:select_board)
    )
    doc_attendee = DocumentAttendee.create!(
      document: doc,
      attendee: attendees(:john_smith_finance),
      status: "present"
    )
    assert_equal doc, doc_attendee.document
  end

  test "belongs to attendee" do
    doc = Document.create!(
      source_file_name: "test_belongs_to_attendee.pdf",
      source_file_hash: "hash_belongs_to_attendee",
      status: 0,
      governing_body: governing_bodies(:select_board)
    )
    doc_attendee = DocumentAttendee.create!(
      document: doc,
      attendee: attendees(:john_smith_finance),
      status: "present"
    )
    assert_equal attendees(:john_smith_finance), doc_attendee.attendee
  end

  test "STATUSES constant contains expected values" do
    assert_equal %w[present absent remote], DocumentAttendee::STATUSES
  end
end
