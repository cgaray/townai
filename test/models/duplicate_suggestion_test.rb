# frozen_string_literal: true

require "test_helper"

class DuplicateSuggestionTest < ActiveSupport::TestCase
  setup do
    @john_smith = people(:john_smith)
    @john_smith_planning = people(:john_smith_planning_person)
    @jon_smith = people(:jon_smith)
    @jane_doe = people(:jane_doe)
  end

  test "requires person_id less than duplicate_person_id" do
    # Ensure john_smith has lower ID
    lower_id_person = @john_smith.id < @john_smith_planning.id ? @john_smith : @john_smith_planning
    higher_id_person = @john_smith.id < @john_smith_planning.id ? @john_smith_planning : @john_smith

    # Valid: smaller ID first
    suggestion = DuplicateSuggestion.new(
      person: lower_id_person,
      duplicate_person: higher_id_person,
      match_type: :exact,
      similarity_score: 0
    )
    assert suggestion.valid?, "Should be valid with smaller person_id first"

    # Invalid: larger ID first
    suggestion = DuplicateSuggestion.new(
      person: higher_id_person,
      duplicate_person: lower_id_person,
      match_type: :exact,
      similarity_score: 0
    )
    assert_not suggestion.valid?, "Should be invalid with larger person_id first"
    assert suggestion.errors[:person_id].any? { |e| e.include?("must be less than") },
           "Expected error about person_id being less than duplicate_person_id"
  end

  test "validates uniqueness of person pair" do
    lower_id, higher_id = [ @john_smith.id, @john_smith_planning.id ].sort
    lower_person = Person.find(lower_id)
    higher_person = Person.find(higher_id)

    DuplicateSuggestion.create!(
      person: lower_person,
      duplicate_person: higher_person,
      match_type: :exact,
      similarity_score: 0
    )

    duplicate = DuplicateSuggestion.new(
      person: lower_person,
      duplicate_person: higher_person,
      match_type: :exact,
      similarity_score: 0
    )
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:person_id], "has already been taken"
  end

  test "scope involving finds suggestions where person is on either side" do
    lower_id, higher_id = [ @john_smith.id, @jane_doe.id ].sort
    lower_person = Person.find(lower_id)
    higher_person = Person.find(higher_id)

    suggestion = DuplicateSuggestion.create!(
      person: lower_person,
      duplicate_person: higher_person,
      match_type: :similar,
      similarity_score: 2
    )

    # Should find when querying either person
    assert_includes DuplicateSuggestion.involving(@john_smith), suggestion
    assert_includes DuplicateSuggestion.involving(@jane_doe), suggestion

    # Should not find unrelated person
    assert_not_includes DuplicateSuggestion.involving(@jon_smith), suggestion
  end

  test "scope involving accepts person ID" do
    lower_id, higher_id = [ @john_smith.id, @jane_doe.id ].sort

    suggestion = DuplicateSuggestion.create!(
      person_id: lower_id,
      duplicate_person_id: higher_id,
      match_type: :exact,
      similarity_score: 0
    )

    assert_includes DuplicateSuggestion.involving(@john_smith.id), suggestion
    assert_includes DuplicateSuggestion.involving(@jane_doe.id), suggestion
  end

  test "other_person returns the other person in the pair" do
    lower_id, higher_id = [ @john_smith.id, @jane_doe.id ].sort
    lower_person = Person.find(lower_id)
    higher_person = Person.find(higher_id)

    suggestion = DuplicateSuggestion.create!(
      person: lower_person,
      duplicate_person: higher_person,
      match_type: :exact,
      similarity_score: 0
    )

    assert_equal higher_person, suggestion.other_person(lower_person)
    assert_equal lower_person, suggestion.other_person(higher_person)
  end

  test "other_person accepts person ID" do
    lower_id, higher_id = [ @john_smith.id, @jane_doe.id ].sort
    lower_person = Person.find(lower_id)
    higher_person = Person.find(higher_id)

    suggestion = DuplicateSuggestion.create!(
      person: lower_person,
      duplicate_person: higher_person,
      match_type: :exact,
      similarity_score: 0
    )

    assert_equal higher_person, suggestion.other_person(lower_id)
    assert_equal lower_person, suggestion.other_person(higher_id)
  end

  test "last_computed_at returns most recent created_at" do
    assert_nil DuplicateSuggestion.last_computed_at

    lower_id, higher_id = [ @john_smith.id, @jane_doe.id ].sort

    suggestion = DuplicateSuggestion.create!(
      person_id: lower_id,
      duplicate_person_id: higher_id,
      match_type: :exact,
      similarity_score: 0
    )

    assert_equal suggestion.created_at, DuplicateSuggestion.last_computed_at
  end

  test "match_type enum works correctly" do
    lower_id, higher_id = [ @john_smith.id, @jane_doe.id ].sort

    exact = DuplicateSuggestion.create!(
      person_id: lower_id,
      duplicate_person_id: higher_id,
      match_type: :exact,
      similarity_score: 0
    )
    assert exact.exact?
    assert_not exact.similar?

    exact.update!(match_type: :similar)
    assert exact.similar?
    assert_not exact.exact?
  end
end
