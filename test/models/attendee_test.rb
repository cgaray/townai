require "test_helper"

class AttendeeTest < ActiveSupport::TestCase
  test "should require name" do
    attendee = Attendee.new(primary_governing_body: "Finance Committee")
    assert_not attendee.valid?
    assert_includes attendee.errors[:name], "can't be blank"
  end

  test "should require primary_governing_body" do
    attendee = Attendee.new(name: "Test Person")
    assert_not attendee.valid?
    assert_includes attendee.errors[:primary_governing_body], "can't be blank"
  end

  test "should auto-set normalized_name from name" do
    attendee = Attendee.new(name: "Dr. John Smith Jr.", primary_governing_body: "Finance Committee")
    attendee.valid?
    assert_equal "john smith", attendee.normalized_name
  end

  test "should auto-set governing_bodies from primary_governing_body" do
    attendee = Attendee.new(name: "John Smith", primary_governing_body: "Finance Committee")
    attendee.valid?
    assert_equal [ "Finance Committee" ], attendee.governing_bodies
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
    assert_equal 1, Attendee.levenshtein_distance("john", "joan")  # h->a is 1 substitution
    assert_equal 3, Attendee.levenshtein_distance("john", "jane")
  end

  test "active scope excludes merged attendees" do
    active_count = Attendee.active.count
    merged_count = Attendee.merged.count
    assert active_count > 0
    assert merged_count > 0
    assert_equal Attendee.count, active_count + merged_count
  end

  test "merged? returns true for merged attendee" do
    merged = attendees(:merged_attendee)
    assert merged.merged?
  end

  test "merged? returns false for active attendee" do
    active = attendees(:john_smith_finance)
    assert_not active.merged?
  end

  test "canonical returns self for non-merged attendee" do
    active = attendees(:john_smith_finance)
    assert_equal active, active.canonical
  end

  test "canonical returns merged_into for merged attendee" do
    merged = attendees(:merged_attendee)
    target = attendees(:john_smith_finance)
    assert_equal target, merged.canonical
  end

  test "canonical follows deep merge chain" do
    # Create a chain: A -> B -> C
    a = Attendee.create!(name: "Chain A", primary_governing_body: "Test Board")
    b = Attendee.create!(name: "Chain B", primary_governing_body: "Test Board 2")
    c = Attendee.create!(name: "Chain C", primary_governing_body: "Test Board 3")

    a.update!(merged_into: b)
    b.update!(merged_into: c)

    assert_equal c, a.canonical
    assert_equal c, b.canonical
    assert_equal c, c.canonical
  end

  test "cannot merge attendee into itself" do
    attendee = attendees(:john_smith_finance)
    attendee.merged_into = attendee

    assert_not attendee.valid?
    assert_includes attendee.errors[:merged_into], "cannot be self"
  end

  test "potential_duplicates finds same name different body" do
    john_finance = attendees(:john_smith_finance)
    duplicates = john_finance.potential_duplicates

    same_name = duplicates[:same_name_different_body]
    assert_includes same_name, attendees(:john_smith_planning)
  end

  test "potential_duplicates finds similar names" do
    john_finance = attendees(:john_smith_finance)
    duplicates = john_finance.potential_duplicates

    similar = duplicates[:similar_name]
    assert_includes similar, attendees(:jon_smith_finance)
  end

  test "potential_duplicates returns empty hash for merged attendee" do
    merged = attendees(:merged_attendee)
    duplicates = merged.potential_duplicates

    assert_kind_of Hash, duplicates
    assert_empty duplicates[:same_name_different_body]
    assert_empty duplicates[:similar_name]
  end

  test "by_appearances orders by document_appearances_count descending" do
    attendees = Attendee.active.by_appearances.limit(3)
    counts = attendees.map(&:document_appearances_count)
    assert_equal counts.sort.reverse, counts
  end

  test "uniqueness constraint on normalized_name + primary_governing_body" do
    existing = attendees(:john_smith_finance)
    duplicate = Attendee.new(
      name: "John Smith",
      normalized_name: existing.normalized_name,
      primary_governing_body: existing.primary_governing_body
    )
    assert_not duplicate.valid?
  end

  test "canonical handles circular references gracefully" do
    # This tests the safeguard against data corruption
    a = Attendee.create!(name: "Cycle A", primary_governing_body: "Board A")
    b = Attendee.create!(name: "Cycle B", primary_governing_body: "Board B")

    # Manually create a cycle (bypassing validations)
    a.update_column(:merged_into_id, b.id)
    b.update_column(:merged_into_id, a.id)

    # Should not infinite loop - returns the last non-cycling node
    assert_nothing_raised { a.canonical }
    assert_nothing_raised { b.canonical }
  end

  test "roles_held returns unique roles from document_attendees" do
    attendee = attendees(:john_smith_finance)
    doc1 = documents(:complete_agenda)
    doc2 = documents(:complete_minutes)

    # Clean up existing links
    DocumentAttendee.where(attendee: attendee).delete_all

    DocumentAttendee.create!(document: doc1, attendee: attendee, role: "chair")
    DocumentAttendee.create!(document: doc2, attendee: attendee, role: "member")

    roles = attendee.roles_held
    assert_includes roles, "chair"
    assert_includes roles, "member"
    assert_equal 2, roles.size
  end

  test "roles_held uses preloaded association when available" do
    attendee = attendees(:john_smith_finance)
    doc = documents(:complete_agenda)

    DocumentAttendee.where(attendee: attendee).delete_all
    DocumentAttendee.create!(document: doc, attendee: attendee, role: "chair")

    # Preload the association
    preloaded = Attendee.includes(:document_attendees).find(attendee.id)

    # Should use the preloaded data without additional queries
    assert preloaded.document_attendees.loaded?
    assert_includes preloaded.roles_held, "chair"
  end

  test "roles_held returns empty array when no roles" do
    attendee = Attendee.create!(name: "No Roles Person", primary_governing_body: "Test Board")
    assert_equal [], attendee.roles_held
  end
end
