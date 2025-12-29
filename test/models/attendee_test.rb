require "test_helper"

class AttendeeTest < ActiveSupport::TestCase
  test "should require name" do
    attendee = Attendee.new(governing_body: "Finance Committee", person: people(:john_smith))
    assert_not attendee.valid?
    assert_includes attendee.errors[:name], "can't be blank"
  end

  test "should require governing_body" do
    attendee = Attendee.new(name: "Test Person", person: people(:john_smith))
    assert_not attendee.valid?
    assert_includes attendee.errors[:governing_body], "can't be blank"
  end

  test "should require person" do
    attendee = Attendee.new(name: "Test Person", governing_body: "Finance Committee")
    assert_not attendee.valid?
    assert_includes attendee.errors[:person], "must exist"
  end

  test "should auto-set normalized_name from name" do
    attendee = Attendee.new(name: "Dr. John Smith Jr.", governing_body: "Finance Committee", person: people(:john_smith))
    attendee.valid?
    assert_equal "john smith", attendee.normalized_name
  end

  test "normalize_name removes titles and punctuation" do
    assert_equal "john smith", Attendee.normalize_name("Dr. John Smith Jr.")
    assert_equal "jane doe", Attendee.normalize_name("Mrs. Jane Doe III")
    assert_equal "bob wilson", Attendee.normalize_name("  Bob   Wilson  ")
    assert_equal "mary jane", Attendee.normalize_name("Mary-Jane")
  end

  test "normalize_name handles edge cases" do
    assert_equal "", Attendee.normalize_name(nil)
    assert_equal "", Attendee.normalize_name("")
  end

  test "levenshtein_distance calculates correctly" do
    assert_equal 0, Attendee.levenshtein_distance("john", "john")
    assert_equal 1, Attendee.levenshtein_distance("john", "jon")
    assert_equal 1, Attendee.levenshtein_distance("john", "joan")
    assert_equal 3, Attendee.levenshtein_distance("john", "jane")
  end

  test "uniqueness constraint on normalized_name + governing_body" do
    existing = attendees(:john_smith_finance)
    duplicate = Attendee.new(
      name: "John Smith",
      normalized_name: existing.normalized_name,
      governing_body: existing.governing_body,
      person: people(:jane_doe)
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:normalized_name], "has already been taken"
  end

  test "belongs to person" do
    attendee = attendees(:john_smith_finance)
    assert_equal people(:john_smith), attendee.person
  end

  test "has many document_attendees" do
    attendee = attendees(:john_smith_finance)
    doc = documents(:complete_agenda)

    DocumentAttendee.where(attendee: attendee).delete_all
    DocumentAttendee.create!(document: doc, attendee: attendee, role: "chair")

    assert_equal 1, attendee.document_attendees.count
  end

  test "has many documents through document_attendees" do
    attendee = attendees(:john_smith_finance)
    doc = documents(:complete_agenda)

    DocumentAttendee.where(attendee: attendee).delete_all
    DocumentAttendee.create!(document: doc, attendee: attendee, role: "chair")

    assert_includes attendee.documents, doc
  end
end
