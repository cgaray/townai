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

    topic_ids.each do |id|
      assert_nil Topic.find_by(id: id), "Topic #{id} should be destroyed"
    end
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
end
