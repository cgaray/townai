# frozen_string_literal: true

require "test_helper"

class ComputeDuplicatesJobTest < ActiveJob::TestCase
  setup do
    @john_smith = people(:john_smith)
    @john_smith_planning = people(:john_smith_planning_person)
    @jon_smith = people(:jon_smith)
    @jane_doe = people(:jane_doe)
    @alice_johnson = people(:alice_johnson)

    # Clear any existing suggestions
    DuplicateSuggestion.delete_all
  end

  test "creates exact match suggestions for same normalized_name" do
    ComputeDuplicatesJob.perform_now

    # john_smith and john_smith_planning have same normalized_name
    suggestion = DuplicateSuggestion.find_by(
      person_id: [ @john_smith.id, @john_smith_planning.id ].min,
      duplicate_person_id: [ @john_smith.id, @john_smith_planning.id ].max
    )

    assert_not_nil suggestion, "Should create suggestion for exact name match"
    assert suggestion.exact?
    assert_equal 0, suggestion.similarity_score
  end

  test "creates similar match suggestions within Levenshtein threshold" do
    ComputeDuplicatesJob.perform_now

    # jon_smith is similar to john_smith (Levenshtein distance = 1)
    suggestion = DuplicateSuggestion.find_by(
      person_id: [ @john_smith.id, @jon_smith.id ].min,
      duplicate_person_id: [ @john_smith.id, @jon_smith.id ].max
    )

    assert_not_nil suggestion, "Should create suggestion for similar name match"
    assert suggestion.similar?
    assert_equal 1, suggestion.similarity_score
  end

  test "does not create suggestions for unrelated names" do
    ComputeDuplicatesJob.perform_now

    # jane_doe and alice_johnson are not similar
    suggestion = DuplicateSuggestion.find_by(
      person_id: [ @jane_doe.id, @alice_johnson.id ].min,
      duplicate_person_id: [ @jane_doe.id, @alice_johnson.id ].max
    )

    assert_nil suggestion, "Should not create suggestion for unrelated names"
  end

  test "clears old suggestions before recompute" do
    # Create an old suggestion
    lower_id, higher_id = [ @jane_doe.id, @alice_johnson.id ].sort
    DuplicateSuggestion.create!(
      person_id: lower_id,
      duplicate_person_id: higher_id,
      match_type: :exact,
      similarity_score: 0
    )

    assert_equal 1, DuplicateSuggestion.count

    ComputeDuplicatesJob.perform_now

    # Old suggestion should be gone, real matches should exist
    suggestion = DuplicateSuggestion.find_by(
      person_id: lower_id,
      duplicate_person_id: higher_id
    )
    assert_nil suggestion, "Should clear old suggestions"
  end

  test "stores pairs with smaller person_id first" do
    ComputeDuplicatesJob.perform_now

    DuplicateSuggestion.find_each do |suggestion|
      assert suggestion.person_id < suggestion.duplicate_person_id,
             "person_id (#{suggestion.person_id}) should be less than duplicate_person_id (#{suggestion.duplicate_person_id})"
    end
  end

  test "respects percentage-based threshold" do
    # With default 20%, a 10-char name allows max distance of 2
    # "john smith" (10 chars) -> max distance = 2
    # "jane doe" (8 chars) -> max distance = 1

    ComputeDuplicatesJob.perform_now

    # All suggestions should have similarity_score within expected threshold
    DuplicateSuggestion.find_each do |suggestion|
      person_name = suggestion.person.normalized_name
      expected_max = [ (person_name.length * 0.2).floor, 1 ].max

      if suggestion.similar?
        assert suggestion.similarity_score <= expected_max,
               "Similarity score #{suggestion.similarity_score} exceeds max #{expected_max} for '#{person_name}'"
      end
    end
  end

  test "handles no duplicate matches" do
    # Create a standalone person with a unique name
    unique_town = Town.create!(name: "Unique Town", normalized_name: "unique town", slug: "unique-town")
    unique_person = Person.create!(
      name: "Completely Unique Name Xyz123",
      normalized_name: "completely unique name xyz123",
      town: unique_town
    )

    # Clear and recompute - should not create suggestions for this unique person
    DuplicateSuggestion.delete_all
    ComputeDuplicatesJob.perform_now

    # The unique person should have no suggestions
    assert_equal 0, DuplicateSuggestion.involving(unique_person).count
  end

  test "job is enqueued to default queue" do
    assert_equal "default", ComputeDuplicatesJob.new.queue_name
  end
end
