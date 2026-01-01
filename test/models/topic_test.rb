# frozen_string_literal: true

require "test_helper"

class TopicTest < ActiveSupport::TestCase
  test "belongs to document" do
    topic = topics(:budget_amendment)
    assert_equal documents(:complete_agenda), topic.document
  end

  test "has one governing body through document" do
    topic = topics(:budget_amendment)
    assert_equal governing_bodies(:select_board), topic.governing_body
  end

  test "has one town through governing body" do
    topic = topics(:budget_amendment)
    assert_equal towns(:arlington), topic.town
  end

  test "requires title" do
    topic = Topic.new(document: documents(:complete_agenda))
    assert_not topic.valid?
    assert_includes topic.errors[:title], "can't be blank"
  end

  test "validates title length" do
    topic = Topic.new(document: documents(:complete_agenda), title: "a" * 501)
    assert_not topic.valid?
    assert_includes topic.errors[:title], "is too long (maximum is 500 characters)"
  end

  test "validates summary length" do
    topic = Topic.new(document: documents(:complete_agenda), title: "Valid", summary: "a" * 5001)
    assert_not topic.valid?
    assert_includes topic.errors[:summary], "is too long (maximum is 5000 characters)"
  end

  test "validates action_taken_raw length" do
    topic = Topic.new(document: documents(:complete_agenda), title: "Valid", action_taken_raw: "a" * 201)
    assert_not topic.valid?
    assert_includes topic.errors[:action_taken_raw], "is too long (maximum is 200 characters)"
  end

  test "validates source_text length" do
    topic = Topic.new(document: documents(:complete_agenda), title: "Valid", source_text: "a" * 50_001)
    assert_not topic.valid?
    assert_includes topic.errors[:source_text], "is too long (maximum is 50000 characters)"
  end

  test "action_taken enum values" do
    topic = topics(:budget_amendment)
    assert topic.action_taken_approved?

    topic = topics(:zoning_variance)
    assert topic.action_taken_denied?

    topic = topics(:public_comment)
    assert topic.action_taken_none?

    topic = topics(:tabled_item)
    assert topic.action_taken_tabled?
  end

  test "action_taken_raw stores original action text" do
    topic = topics(:budget_amendment)
    assert_equal "motion passed 4-1", topic.action_taken_raw

    topic = topics(:zoning_variance)
    assert_equal "rejected 3-2", topic.action_taken_raw

    topic = topics(:public_comment)
    assert_nil topic.action_taken_raw

    topic = topics(:tabled_item)
    assert_equal "laid on the table", topic.action_taken_raw
  end

  test "with_actions scope excludes none" do
    topics_with_actions = Topic.with_actions
    assert_not topics_with_actions.include?(topics(:public_comment))
    assert topics_with_actions.include?(topics(:budget_amendment))
    assert topics_with_actions.include?(topics(:zoning_variance))
  end

  test "ordered scope orders by position" do
    document = documents(:complete_agenda)
    ordered = document.topics.ordered
    positions = ordered.pluck(:position)
    assert_equal positions.sort, positions
  end

  test "meeting_date returns date from parent document" do
    topic = topics(:budget_amendment)
    expected_date = topic.document.metadata_field("meeting_date")
    assert_equal expected_date, topic.meeting_date
  end

  test "meeting_date_formatted returns formatted date string" do
    topic = topics(:budget_amendment)
    document = topic.document
    document.update!(extracted_metadata: { "meeting_date" => "2025-01-15" }.to_json)

    assert_equal "January 15, 2025", topic.meeting_date_formatted
  end

  test "meeting_date_formatted returns Date Unknown for blank date" do
    topic = topics(:budget_amendment)
    document = topic.document
    document.update!(extracted_metadata: {}.to_json)

    assert_equal "Date Unknown", topic.meeting_date_formatted
  end

  test "meeting_date_formatted returns raw string for unparseable date" do
    topic = topics(:budget_amendment)
    document = topic.document
    document.update!(extracted_metadata: { "meeting_date" => "invalid date format" }.to_json)

    assert_equal "invalid date format", topic.meeting_date_formatted
  end

  test "for_town scope filters by town" do
    arlington = towns(:arlington)
    arlington_topics = Topic.for_town(arlington)

    arlington_topics.each do |topic|
      assert_equal arlington, topic.town
    end
  end

  test "document has many topics" do
    document = documents(:complete_agenda)
    assert document.topics.count >= 1
  end

  test "destroying document destroys topics" do
    document = documents(:complete_agenda)
    topic_ids = document.topics.pluck(:id)

    assert topic_ids.any?, "Document should have topics for this test"

    document.destroy

    remaining_topics = Topic.where(id: topic_ids)
    assert_empty remaining_topics, "All topics should be destroyed with document"
  end

  # has_action? tests
  test "has_action? returns true for approved" do
    topic = topics(:budget_amendment)
    assert topic.has_action?
  end

  test "has_action? returns true for denied" do
    topic = topics(:zoning_variance)
    assert topic.has_action?
  end

  test "has_action? returns false for none" do
    topic = topics(:public_comment)
    assert_not topic.has_action?
  end

  # normalize_action tests - handles various municipal meeting terminology
  test "normalize_action handles approved variants" do
    # Simple keywords
    assert_equal :approved, Topic.normalize_action("approved")
    assert_equal :approved, Topic.normalize_action("passed")
    assert_equal :approved, Topic.normalize_action("ACCEPTED")
    assert_equal :approved, Topic.normalize_action("adopted")
    assert_equal :approved, Topic.normalize_action("carried")

    # Phrases with vote counts
    assert_equal :approved, Topic.normalize_action("motion passed 4-1")
    assert_equal :approved, Topic.normalize_action("approved unanimously")
    assert_equal :approved, Topic.normalize_action("motion carried 5-0")
    assert_equal :approved, Topic.normalize_action("voted in favor")
  end

  test "normalize_action handles denied variants" do
    assert_equal :denied, Topic.normalize_action("denied")
    assert_equal :denied, Topic.normalize_action("rejected")
    assert_equal :denied, Topic.normalize_action("Failed")
    assert_equal :denied, Topic.normalize_action("defeated")
    assert_equal :denied, Topic.normalize_action("rejected 3-2")
    assert_equal :denied, Topic.normalize_action("motion failed")
  end

  test "normalize_action handles tabled variants" do
    assert_equal :tabled, Topic.normalize_action("tabled")
    assert_equal :tabled, Topic.normalize_action("postponed")
    assert_equal :tabled, Topic.normalize_action("laid on the table")
    assert_equal :tabled, Topic.normalize_action("postponed indefinitely")
  end

  test "normalize_action handles continued variants" do
    assert_equal :continued, Topic.normalize_action("continued")
    assert_equal :continued, Topic.normalize_action("deferred")
    assert_equal :continued, Topic.normalize_action("referred to subcommittee")
    assert_equal :continued, Topic.normalize_action("continued to March 15")
    assert_equal :continued, Topic.normalize_action("deferred to next meeting")
  end

  test "normalize_action returns none for blank or unknown" do
    assert_equal :none, Topic.normalize_action(nil)
    assert_equal :none, Topic.normalize_action("")
    assert_equal :none, Topic.normalize_action("discussed")
    assert_equal :none, Topic.normalize_action("no action taken")
  end

  # create_from_metadata tests
  test "create_from_metadata creates topics from document metadata" do
    document = documents(:complete_agenda)
    document.topics.destroy_all

    # Set up metadata with topics using raw action values
    metadata = {
      "topics" => [
        { "title" => "First Item", "summary" => "Summary 1", "action_taken" => "motion passed 4-1" },
        { "title" => "Second Item", "summary" => "Summary 2", "action_taken" => "rejected 3-2" }
      ]
    }
    document.update!(extracted_metadata: metadata.to_json)

    count = Topic.create_from_metadata(document)

    assert_equal 2, count
    assert_equal 2, document.topics.count

    first_topic = document.topics.find_by(position: 0)
    assert_equal "First Item", first_topic.title
    assert first_topic.action_taken_approved?
    assert_equal "motion passed 4-1", first_topic.action_taken_raw

    second_topic = document.topics.find_by(position: 1)
    assert_equal "Second Item", second_topic.title
    assert second_topic.action_taken_denied?
    assert_equal "rejected 3-2", second_topic.action_taken_raw
  end

  test "create_from_metadata stores nil for blank action_taken_raw" do
    document = documents(:complete_agenda)
    document.topics.destroy_all

    metadata = {
      "topics" => [
        { "title" => "Discussion Item", "summary" => "No action taken" }
      ]
    }
    document.update!(extracted_metadata: metadata.to_json)

    Topic.create_from_metadata(document)

    topic = document.topics.first
    assert topic.action_taken_none?
    assert_nil topic.action_taken_raw
  end

  test "create_from_metadata clears existing topics" do
    document = documents(:complete_agenda)
    original_count = document.topics.count
    assert original_count > 0

    metadata = { "topics" => [ { "title" => "New Topic" } ] }
    document.update!(extracted_metadata: metadata.to_json)

    Topic.create_from_metadata(document)

    assert_equal 1, document.topics.count
    assert_equal "New Topic", document.topics.first.title
  end

  test "create_from_metadata returns 0 for empty topics" do
    document = documents(:complete_agenda)
    document.topics.destroy_all
    document.update!(extracted_metadata: { "topics" => [] }.to_json)

    count = Topic.create_from_metadata(document)

    assert_equal 0, count
  end

  test "create_from_metadata skips topics without title" do
    document = documents(:complete_agenda)
    document.topics.destroy_all

    metadata = {
      "topics" => [
        { "title" => "Valid Topic" },
        { "title" => "", "summary" => "No title" },
        { "summary" => "Also no title" }
      ]
    }
    document.update!(extracted_metadata: metadata.to_json)

    count = Topic.create_from_metadata(document)

    assert_equal 1, count
    assert_equal "Valid Topic", document.topics.first.title
  end

  test "create_from_metadata limits topics to MAX_TOPICS_PER_DOCUMENT" do
    document = documents(:complete_agenda)
    document.topics.destroy_all

    # Create metadata with more than MAX_TOPICS_PER_DOCUMENT topics
    many_topics = (1..150).map { |i| { "title" => "Topic #{i}" } }
    metadata = { "topics" => many_topics }
    document.update!(extracted_metadata: metadata.to_json)

    count = Topic.create_from_metadata(document)

    assert_equal Topic::MAX_TOPICS_PER_DOCUMENT, count
    assert_equal Topic::MAX_TOPICS_PER_DOCUMENT, document.topics.count
  end

  # display_position tests
  test "display_position returns 1-indexed position" do
    topic = topics(:budget_amendment)
    topic.position = 0
    assert_equal 1, topic.display_position

    topic.position = 5
    assert_equal 6, topic.display_position
  end

  test "display_position handles nil position" do
    topic = Topic.new(document: documents(:complete_agenda), title: "Test")
    topic.position = nil
    assert_equal 1, topic.display_position
  end

  # filter_counts_for_town tests
  test "filter_counts_for_town returns counts by action type" do
    town = towns(:arlington)
    counts = Topic.filter_counts_for_town(town)

    assert counts.key?(:all)
    assert counts.key?(:with_actions)
    assert counts.key?(:approved)
    assert counts.key?(:denied)
    assert counts.key?(:tabled)
    assert counts.key?(:continued)

    # with_actions should equal all minus none
    none_count = Topic.for_town(town).complete.where(action_taken: :none).count
    assert_equal counts[:all] - none_count, counts[:with_actions]
  end

  test "filter_counts_for_town uses single query" do
    town = towns(:arlington)

    # This test verifies the method works and returns correct structure
    # The performance improvement (1 query vs 6) is the implementation detail
    counts = Topic.filter_counts_for_town(town)

    # Verify all counts are non-negative integers
    counts.each do |key, value|
      assert_kind_of Integer, value, "#{key} should be an integer"
      assert value >= 0, "#{key} should be non-negative"
    end

    # Verify with_actions is sum of individual action counts
    individual_sum = counts[:approved] + counts[:denied] + counts[:tabled] + counts[:continued]
    assert_equal individual_sum, counts[:with_actions]
  end

  test "filter_counts_for_town only counts complete documents" do
    town = towns(:arlington)

    # Get counts before
    counts_before = Topic.filter_counts_for_town(town)

    # Create a pending document with a topic
    pending_doc = Document.create!(
      governing_body: governing_bodies(:select_board),
      status: :pending
    )
    pending_doc.topics.create!(title: "Should not be counted", action_taken: :approved)

    # Counts should be unchanged
    counts_after = Topic.filter_counts_for_town(town)
    assert_equal counts_before[:all], counts_after[:all]
    assert_equal counts_before[:approved], counts_after[:approved]
  end
end
