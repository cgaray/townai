require "test_helper"

class PersonTest < ActiveSupport::TestCase
  test "should require name" do
    person = Person.new
    assert_not person.valid?
    assert_includes person.errors[:name], "can't be blank"
  end

  test "should auto-set normalized_name from name" do
    person = Person.new(name: "Dr. John Smith Jr.")
    person.valid?
    assert_equal "john smith", person.normalized_name
  end

  test "has many attendees" do
    person = people(:john_smith)
    assert person.attendees.any?
  end

  test "has many document_attendees through attendees" do
    person = people(:john_smith)
    attendee = attendees(:john_smith_finance)
    doc = documents(:complete_agenda)

    DocumentAttendee.where(attendee: attendee).delete_all
    DocumentAttendee.create!(document: doc, attendee: attendee, role: "chair")

    assert_equal 1, person.document_attendees.count
  end

  test "has many documents through document_attendees" do
    person = people(:john_smith)
    attendee = attendees(:john_smith_finance)
    doc = documents(:complete_agenda)

    DocumentAttendee.where(attendee: attendee).delete_all
    DocumentAttendee.create!(document: doc, attendee: attendee, role: "chair")

    assert_includes person.documents, doc
  end

  test "governing_body_names returns unique extracted body names from attendees" do
    person = people(:john_smith)
    bodies = person.governing_body_names

    assert_includes bodies, "Select Board"
  end

  test "governing_bodies returns GoverningBody records" do
    person = people(:john_smith)

    bodies = person.governing_bodies
    assert bodies.all? { |b| b.is_a?(GoverningBody) }
    assert_includes bodies.map(&:name), "Select Board"
  end

  test "primary_governing_body returns most common GoverningBody" do
    person = people(:john_smith)
    expected_gb = attendees(:john_smith_finance).governing_body

    assert_equal expected_gb, person.primary_governing_body
  end

  test "roles_held returns unique roles from document_attendees" do
    person = people(:john_smith)
    attendee = attendees(:john_smith_finance)
    doc1 = documents(:complete_agenda)
    doc2 = documents(:complete_minutes)

    DocumentAttendee.where(attendee: attendee).delete_all
    DocumentAttendee.create!(document: doc1, attendee: attendee, role: "chair")
    DocumentAttendee.create!(document: doc2, attendee: attendee, role: "member")

    roles = person.roles_held
    assert_includes roles, "chair"
    assert_includes roles, "member"
    assert_equal 2, roles.size
  end

  test "potential_duplicates finds same name" do
    john = people(:john_smith)
    duplicates = john.potential_duplicates

    same_name = duplicates[:same_name]
    assert_includes same_name, people(:john_smith_planning_person)
  end

  test "potential_duplicates finds similar names" do
    john = people(:john_smith)
    duplicates = john.potential_duplicates

    similar = duplicates[:similar_name]
    assert_includes similar, people(:jon_smith)
  end

  test "by_appearances orders by document_appearances_count descending" do
    people = Person.by_appearances.limit(3)
    counts = people.map(&:document_appearances_count)
    assert_equal counts.sort.reverse, counts
  end

  test "update_appearances_count! updates counter cache" do
    person = people(:john_smith)
    attendee = attendees(:john_smith_finance)
    doc = documents(:complete_agenda)

    DocumentAttendee.where(attendee: attendee).delete_all
    person.update_column(:document_appearances_count, 0)

    DocumentAttendee.create!(document: doc, attendee: attendee, role: "chair")
    person.update_appearances_count!

    assert_equal 1, person.reload.document_appearances_count
  end

  test "co_people returns people who appear in same documents" do
    john_person = people(:john_smith)
    jane_person = people(:jane_doe)
    john_attendee = attendees(:john_smith_finance)
    jane_attendee = attendees(:jane_doe_finance)
    doc = documents(:complete_agenda)

    DocumentAttendee.where(document: doc).delete_all
    DocumentAttendee.create!(document: doc, attendee: john_attendee, role: "chair")
    DocumentAttendee.create!(document: doc, attendee: jane_attendee, role: "member")

    co_people = john_person.co_people
    assert_includes co_people, jane_person
  end

  test "co_people excludes self" do
    person = people(:john_smith)
    assert_not_includes person.co_people, person
  end
end
