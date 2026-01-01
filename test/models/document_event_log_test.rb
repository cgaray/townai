# frozen_string_literal: true

require "test_helper"

class DocumentEventLogTest < ActiveSupport::TestCase
  setup do
    @document = documents(:complete_agenda)
  end

  test "should create valid event log" do
    log = DocumentEventLog.new(
      document: @document,
      event_type: "extraction_completed"
    )
    assert log.valid?
    assert log.save
  end

  test "requires document" do
    log = DocumentEventLog.new(
      event_type: "extraction_completed"
    )
    assert_not log.valid?
    assert_includes log.errors[:document], "must exist"
  end

  test "requires event_type" do
    log = DocumentEventLog.new(
      document: @document
    )
    assert_not log.valid?
    assert_includes log.errors[:event_type], "can't be blank"
  end

  test "event_types constant contains expected values" do
    assert_includes DocumentEventLog::EVENT_TYPES, "uploaded"
    assert_includes DocumentEventLog::EVENT_TYPES, "extraction_started"
    assert_includes DocumentEventLog::EVENT_TYPES, "extraction_completed"
    assert_includes DocumentEventLog::EVENT_TYPES, "extraction_failed"
  end

  test "accepts common event types" do
    valid_events = %w[uploaded extraction_started extraction_completed extraction_failed]

    valid_events.each do |event|
      log = DocumentEventLog.new(
        document: @document,
        event_type: event
      )
      assert log.valid?, "Expected event_type '#{event}' to be valid"
    end
  end

  test "stores metadata as JSON" do
    log = DocumentEventLog.create!(
      document: @document,
      event_type: "extraction_completed",
      metadata: { duration: 5.2, tokens_used: 1500 }.to_json
    )

    parsed = JSON.parse(log.metadata)
    assert_equal 5.2, parsed["duration"]
    assert_equal 1500, parsed["tokens_used"]
  end

  test "success? returns true for completed event" do
    completed_log = DocumentEventLog.new(event_type: "extraction_completed")
    assert completed_log.success?
  end

  test "failure? returns true for failed event" do
    failed_log = DocumentEventLog.new(event_type: "extraction_failed")
    assert failed_log.failure?
  end

  test "failure? returns false for non-failed events" do
    completed_log = DocumentEventLog.new(event_type: "extraction_completed")
    assert_not completed_log.failure?
  end

  test "recent scope orders by created_at desc" do
    old_log = DocumentEventLog.create!(
      document: @document,
      event_type: "extraction_started",
      created_at: 1.hour.ago
    )
    new_log = DocumentEventLog.create!(
      document: @document,
      event_type: "extraction_completed",
      created_at: Time.current
    )

    logs = DocumentEventLog.recent
    assert_equal new_log.id, logs.first.id
  end

  test "by_document scope filters by document" do
    other_document = documents(:complete_minutes)

    log1 = DocumentEventLog.create!(document: @document, event_type: "extraction_completed")
    log2 = DocumentEventLog.create!(document: other_document, event_type: "extraction_completed")

    logs = DocumentEventLog.by_document(@document)
    assert_includes logs, log1
    assert_not_includes logs, log2
  end
end
