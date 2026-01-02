# frozen_string_literal: true

require "test_helper"

class MeetingTimelineTest < ActiveSupport::TestCase
  # Create a test class that includes the concern
  class TestController
    include MeetingTimeline

    # Expose private methods for testing
    public :build_meetings_hierarchy, :parse_meeting_date, :merge_meeting_topics
  end

  setup do
    @controller = TestController.new
  end

  test "build_meetings_hierarchy returns empty hash for empty documents" do
    result = @controller.build_meetings_hierarchy([])
    assert_equal({}, result)
  end

  test "build_meetings_hierarchy groups documents by year, month, day" do
    doc1 = create_doc_with_date("2024-12-15")
    doc2 = create_doc_with_date("2024-12-20")
    doc3 = create_doc_with_date("2024-11-10")

    result = @controller.build_meetings_hierarchy([ doc1, doc2, doc3 ])

    assert_equal [ 2024 ], result.keys
    assert_equal 3, result[2024][:count]
    assert_equal [ 12, 11 ], result[2024][:months].keys
    assert_equal "December", result[2024][:months][12][:name]
    assert_equal "November", result[2024][:months][11][:name]
    assert_equal [ 20, 15 ], result[2024][:months][12][:days].keys
    assert_equal [ 10 ], result[2024][:months][11][:days].keys
  end

  test "build_meetings_hierarchy sorts years descending" do
    doc1 = create_doc_with_date("2020-01-01")
    doc2 = create_doc_with_date("2024-01-01")
    doc3 = create_doc_with_date("2022-01-01")

    result = @controller.build_meetings_hierarchy([ doc1, doc2, doc3 ])

    assert_equal [ 2024, 2022, 2020 ], result.keys
  end

  test "build_meetings_hierarchy sorts months descending within year" do
    doc1 = create_doc_with_date("2024-03-01")
    doc2 = create_doc_with_date("2024-11-01")
    doc3 = create_doc_with_date("2024-07-01")

    result = @controller.build_meetings_hierarchy([ doc1, doc2, doc3 ])

    assert_equal [ 11, 7, 3 ], result[2024][:months].keys
  end

  test "build_meetings_hierarchy sorts days descending within month" do
    doc1 = create_doc_with_date("2024-12-05")
    doc2 = create_doc_with_date("2024-12-25")
    doc3 = create_doc_with_date("2024-12-15")

    result = @controller.build_meetings_hierarchy([ doc1, doc2, doc3 ])

    assert_equal [ 25, 15, 5 ], result[2024][:months][12][:days].keys
  end

  test "build_meetings_hierarchy groups multiple documents on same day by governing body" do
    gb1 = governing_bodies(:select_board)
    gb2 = governing_bodies(:redevelopment_board)
    doc1 = create_doc_with_date("2024-12-15", governing_body: gb1)
    doc2 = create_doc_with_date("2024-12-15", governing_body: gb2)

    result = @controller.build_meetings_hierarchy([ doc1, doc2 ])

    # Two different governing bodies = two separate meeting items
    items = result[2024][:months][12][:days][15]
    assert_equal 2, items.size
    assert_includes items.flat_map { |i| i[:documents] }, doc1
    assert_includes items.flat_map { |i| i[:documents] }, doc2
  end

  test "build_meetings_hierarchy combines agenda and minutes for same meeting" do
    gb = governing_bodies(:select_board)
    agenda = create_doc_with_date("2024-12-15", governing_body: gb, doc_type: "agenda")
    minutes = create_doc_with_date("2024-12-15", governing_body: gb, doc_type: "minutes")

    result = @controller.build_meetings_hierarchy([ agenda, minutes ])

    # Same governing body and date = one meeting item with two documents
    items = result[2024][:months][12][:days][15]
    assert_equal 1, items.size
    assert_equal 2, items.first[:documents].size
    assert_includes items.first[:documents], agenda
    assert_includes items.first[:documents], minutes
  end

  test "build_meetings_hierarchy skips documents with nil meeting_date" do
    doc1 = create_doc_with_date("2024-12-15")
    doc2 = create_doc_with_date(nil)

    result = @controller.build_meetings_hierarchy([ doc1, doc2 ])

    assert_equal 1, result[2024][:count]
  end

  test "build_meetings_hierarchy skips documents with empty meeting_date" do
    doc1 = create_doc_with_date("2024-12-15")
    doc2 = create_doc_with_date("")

    result = @controller.build_meetings_hierarchy([ doc1, doc2 ])

    assert_equal 1, result[2024][:count]
  end

  test "build_meetings_hierarchy skips documents with invalid meeting_date" do
    doc1 = create_doc_with_date("2024-12-15")
    doc2 = create_doc_with_date("not-a-date")

    result = @controller.build_meetings_hierarchy([ doc1, doc2 ])

    assert_equal 1, result[2024][:count]
  end

  test "build_meetings_hierarchy includes extra data when provided" do
    doc = create_doc_with_date("2024-12-15")
    extra_data = { doc.id => { role: "Chair", status: "present" } }

    result = @controller.build_meetings_hierarchy([ doc ], extra_data)

    item = result[2024][:months][12][:days][15].first
    assert_equal({ role: "Chair", status: "present" }, item[:extras][doc.id])
  end

  test "build_meetings_hierarchy has empty extras when no extra data" do
    doc = create_doc_with_date("2024-12-15")

    result = @controller.build_meetings_hierarchy([ doc ], {})

    item = result[2024][:months][12][:days][15].first
    assert_empty item[:extras]
  end

  test "parse_meeting_date returns nil for blank string" do
    assert_nil @controller.parse_meeting_date("")
    assert_nil @controller.parse_meeting_date(nil)
  end

  test "parse_meeting_date returns nil for invalid date" do
    assert_nil @controller.parse_meeting_date("not-a-date")
    assert_nil @controller.parse_meeting_date("2024-13-45")
  end

  test "parse_meeting_date parses valid date string" do
    date = @controller.parse_meeting_date("2024-12-15")
    assert_equal Date.new(2024, 12, 15), date
  end

  # merge_meeting_topics tests

  test "merge_meeting_topics returns empty array for empty documents" do
    result = @controller.merge_meeting_topics([], {})
    assert_equal [], result
  end

  test "merge_meeting_topics returns topics from single document" do
    doc = create_doc_with_date("2024-12-15", doc_type: "agenda")
    topic = Topic.create!(document: doc, title: "Budget Review", position: 0)

    result = @controller.merge_meeting_topics([ doc ], {})

    assert_equal 1, result.size
    assert_equal topic, result.first[:topic]
    assert_equal doc, result.first[:document]
    assert_equal "agenda", result.first[:doc_type]
  end

  test "merge_meeting_topics deduplicates topics by normalized title" do
    agenda = create_doc_with_date("2024-12-15", doc_type: "agenda")
    minutes = create_doc_with_date("2024-12-15", doc_type: "minutes")
    Topic.create!(document: agenda, title: "Budget Review", position: 0)
    minutes_topic = Topic.create!(document: minutes, title: "Budget Review", position: 0, action_taken: :approved)

    result = @controller.merge_meeting_topics([ agenda, minutes ], {})

    assert_equal 1, result.size
    assert_equal minutes_topic, result.first[:topic]
  end

  test "merge_meeting_topics prefers minutes over agenda for same topic" do
    agenda = create_doc_with_date("2024-12-15", doc_type: "agenda")
    minutes = create_doc_with_date("2024-12-15", doc_type: "minutes")
    agenda_topic = Topic.create!(document: agenda, title: "Budget Review", position: 0, action_taken: :none)
    minutes_topic = Topic.create!(document: minutes, title: "Budget Review", position: 0, action_taken: :approved)

    # Test with agenda first
    result = @controller.merge_meeting_topics([ agenda, minutes ], {})
    assert_equal minutes_topic, result.first[:topic]
    assert_equal "minutes", result.first[:doc_type]

    # Test with minutes first - should still prefer minutes
    result = @controller.merge_meeting_topics([ minutes, agenda ], {})
    assert_equal minutes_topic, result.first[:topic]
    assert_equal "minutes", result.first[:doc_type]
  end

  test "merge_meeting_topics preserves first minutes version when multiple minutes exist" do
    minutes1 = create_doc_with_date("2024-12-15", doc_type: "minutes")
    minutes2 = create_doc_with_date("2024-12-15", doc_type: "minutes")
    first_topic = Topic.create!(document: minutes1, title: "Budget Review", position: 0, action_taken: :approved)
    Topic.create!(document: minutes2, title: "Budget Review", position: 0, action_taken: :denied)

    result = @controller.merge_meeting_topics([ minutes1, minutes2 ], {})

    assert_equal 1, result.size
    assert_equal first_topic, result.first[:topic]
  end

  test "merge_meeting_topics handles case-insensitive title matching" do
    agenda = create_doc_with_date("2024-12-15", doc_type: "agenda")
    minutes = create_doc_with_date("2024-12-15", doc_type: "minutes")
    Topic.create!(document: agenda, title: "BUDGET REVIEW", position: 0)
    minutes_topic = Topic.create!(document: minutes, title: "budget review", position: 0, action_taken: :approved)

    result = @controller.merge_meeting_topics([ agenda, minutes ], {})

    assert_equal 1, result.size
    assert_equal minutes_topic, result.first[:topic]
  end

  test "merge_meeting_topics sorts by position" do
    doc = create_doc_with_date("2024-12-15", doc_type: "minutes")
    topic3 = Topic.create!(document: doc, title: "Third Item", position: 2)
    topic1 = Topic.create!(document: doc, title: "First Item", position: 0)
    topic2 = Topic.create!(document: doc, title: "Second Item", position: 1)

    result = @controller.merge_meeting_topics([ doc ], {})

    assert_equal [ topic1, topic2, topic3 ], result.map { |t| t[:topic] }
  end

  test "merge_meeting_topics uses preloaded topics from extras when available" do
    doc = create_doc_with_date("2024-12-15", doc_type: "agenda")
    # Don't create topics in DB - pass them via extras
    mock_topic = Topic.new(title: "Preloaded Topic", position: 0)
    extras = { doc.id => { topics: [ mock_topic ] } }

    result = @controller.merge_meeting_topics([ doc ], extras)

    assert_equal 1, result.size
    assert_equal mock_topic, result.first[:topic]
  end

  private

  def create_doc_with_date(meeting_date, governing_body: nil, doc_type: nil)
    metadata = if meeting_date
      data = { "meeting_date" => meeting_date }
      data["governing_body"] = governing_body&.name if governing_body
      data["document_type"] = doc_type if doc_type
      data.to_json
    end
    Document.create!(
      status: :complete,
      governing_body: governing_body,
      extracted_metadata: metadata
    )
  end
end
