# frozen_string_literal: true

require "test_helper"

class MeetingTimelineTest < ActiveSupport::TestCase
  # Create a test class that includes the concern
  class TestController
    include MeetingTimeline

    # Expose private methods for testing
    public :build_meetings_hierarchy, :parse_meeting_date
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

  test "build_meetings_hierarchy groups multiple documents on same day" do
    doc1 = create_doc_with_date("2024-12-15")
    doc2 = create_doc_with_date("2024-12-15")

    result = @controller.build_meetings_hierarchy([ doc1, doc2 ])

    items = result[2024][:months][12][:days][15]
    assert_equal 2, items.size
    assert_equal doc1, items[0][:document]
    assert_equal doc2, items[1][:document]
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
    assert_equal({ role: "Chair", status: "present" }, item[:extra])
  end

  test "build_meetings_hierarchy omits extra key when no extra data" do
    doc = create_doc_with_date("2024-12-15")

    result = @controller.build_meetings_hierarchy([ doc ], {})

    item = result[2024][:months][12][:days][15].first
    assert_not item.key?(:extra)
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

  private

  def create_doc_with_date(meeting_date)
    metadata = meeting_date ? { "meeting_date" => meeting_date }.to_json : nil
    Document.create!(
      status: :complete,
      extracted_metadata: metadata
    )
  end
end
