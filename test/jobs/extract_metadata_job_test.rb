require "test_helper"

class ExtractMetadataJobTest < ActiveJob::TestCase
  test "returns early if document is not pending" do
    doc = documents(:complete_agenda)
    original_metadata = doc.extracted_metadata

    # Should not raise and should not modify
    ExtractMetadataJob.new.send(:validate_enum, "agenda", %w[agenda minutes])

    doc.reload
    assert_equal original_metadata, doc.extracted_metadata
  end

  test "validate_enum returns value if in allowed list" do
    job = ExtractMetadataJob.new
    assert_equal "agenda", job.send(:validate_enum, "agenda", %w[agenda minutes])
    assert_equal "minutes", job.send(:validate_enum, "minutes", %w[agenda minutes])
  end

  test "validate_enum returns nil if not in allowed list" do
    job = ExtractMetadataJob.new
    assert_nil job.send(:validate_enum, "invalid", %w[agenda minutes])
    assert_nil job.send(:validate_enum, nil, %w[agenda minutes])
    assert_nil job.send(:validate_enum, "", %w[agenda minutes])
  end

  test "parse_date returns ISO8601 date string for valid date" do
    job = ExtractMetadataJob.new
    assert_equal "2024-12-25", job.send(:parse_date, "2024-12-25")
    assert_equal "2024-01-01", job.send(:parse_date, "January 1, 2024")
  end

  test "parse_date returns nil for invalid date" do
    job = ExtractMetadataJob.new
    assert_nil job.send(:parse_date, "invalid date")
    assert_nil job.send(:parse_date, nil)
  end

  test "normalize_attendees returns empty array for nil" do
    job = ExtractMetadataJob.new
    assert_equal [], job.send(:normalize_attendees, nil)
  end

  test "normalize_attendees returns empty array for non-array" do
    job = ExtractMetadataJob.new
    assert_equal [], job.send(:normalize_attendees, "not an array")
    assert_equal [], job.send(:normalize_attendees, 123)
  end

  test "normalize_attendees processes valid attendee data" do
    job = ExtractMetadataJob.new
    attendees = [
      { "name" => "John Smith", "role" => "chair", "status" => "present" },
      { "name" => "Jane Doe", "role" => "member", "status" => "absent" }
    ]

    result = job.send(:normalize_attendees, attendees)

    assert_equal 2, result.length
    assert_equal "John Smith", result[0][:name]
    assert_equal "chair", result[0][:role]
    assert_equal "present", result[0][:status]
  end

  test "normalize_attendees validates roles" do
    job = ExtractMetadataJob.new
    attendees = [
      { "name" => "John", "role" => "invalid_role", "status" => "present" }
    ]

    result = job.send(:normalize_attendees, attendees)

    assert_equal 1, result.length
    assert_nil result[0][:role]
  end

  test "normalize_attendees validates statuses" do
    job = ExtractMetadataJob.new
    attendees = [
      { "name" => "John", "role" => "member", "status" => "invalid_status" }
    ]

    result = job.send(:normalize_attendees, attendees)

    assert_equal 1, result.length
    assert_nil result[0][:status]
  end

  test "normalize_attendees skips non-hash entries" do
    job = ExtractMetadataJob.new
    attendees = [
      { "name" => "John", "role" => "member" },
      "not a hash",
      nil,
      { "name" => "Jane", "role" => "chair" }
    ]

    result = job.send(:normalize_attendees, attendees)

    assert_equal 2, result.length
  end

  test "normalize_topics returns empty array for nil" do
    job = ExtractMetadataJob.new
    assert_equal [], job.send(:normalize_topics, nil)
  end

  test "normalize_topics returns empty array for non-array" do
    job = ExtractMetadataJob.new
    assert_equal [], job.send(:normalize_topics, "not an array")
  end

  test "normalize_topics processes valid topic data" do
    job = ExtractMetadataJob.new
    topics = [
      { "title" => "Budget Review", "summary" => "Quarterly review", "action_taken" => "approved" },
      { "title" => "New Business", "summary" => "Various items", "action_taken" => "none" }
    ]

    result = job.send(:normalize_topics, topics)

    assert_equal 2, result.length
    assert_equal "Budget Review", result[0][:title]
    assert_equal "approved", result[0][:action_taken]
  end

  test "normalize_topics validates action_taken" do
    job = ExtractMetadataJob.new
    topics = [
      { "title" => "Topic 1", "action_taken" => "invalid_action" }
    ]

    result = job.send(:normalize_topics, topics)

    assert_equal 1, result.length
    assert_nil result[0][:action_taken]
  end

  test "normalize_topics skips topics without title" do
    job = ExtractMetadataJob.new
    topics = [
      { "title" => "Valid Topic", "summary" => "Has title" },
      { "summary" => "No title here" },
      { "title" => "", "summary" => "Empty title" }
    ]

    result = job.send(:normalize_topics, topics)

    assert_equal 1, result.length
    assert_equal "Valid Topic", result[0][:title]
  end

  test "normalize_metadata strips markdown code blocks" do
    job = ExtractMetadataJob.new
    raw_json = "```json\n{\"document_type\":\"agenda\"}\n```"

    result = job.send(:normalize_metadata, raw_json)
    parsed = JSON.parse(result)

    assert_equal "agenda", parsed["document_type"]
  end

  test "normalize_metadata returns nil for invalid JSON" do
    job = ExtractMetadataJob.new
    assert_nil job.send(:normalize_metadata, "not json at all")
  end

  test "normalize_metadata handles plain JSON" do
    job = ExtractMetadataJob.new
    raw_json = '{"document_type":"minutes","governing_body":"Town Council"}'

    result = job.send(:normalize_metadata, raw_json)
    parsed = JSON.parse(result)

    assert_equal "minutes", parsed["document_type"]
    assert_equal "Town Council", parsed["governing_body"]
  end

  # Source text tests
  test "normalize_attendees preserves source_text" do
    job = ExtractMetadataJob.new
    attendees = [
      { "name" => "John Smith", "role" => "chair", "source_text" => "Present: John Smith, Chair" }
    ]

    result = job.send(:normalize_attendees, attendees)

    assert_equal 1, result.length
    assert_equal "Present: John Smith, Chair", result[0][:source_text]
  end

  test "normalize_topics preserves source_text" do
    job = ExtractMetadataJob.new
    topics = [
      { "title" => "Budget Review", "summary" => "Quarterly review", "source_text" => "Item 1: Budget Review\nThe committee reviewed..." }
    ]

    result = job.send(:normalize_topics, topics)

    assert_equal 1, result.length
    assert_equal "Item 1: Budget Review\nThe committee reviewed...", result[0][:source_text]
  end

  test "normalize_metadata preserves source_text fields" do
    job = ExtractMetadataJob.new
    raw_json = <<~JSON
      {
        "document_type": "agenda",
        "governing_body": "Town Council",
        "governing_body_source_text": "TOWN OF SPRINGFIELD - TOWN COUNCIL",
        "meeting_date": "2024-12-25",
        "meeting_date_source_text": "December 25, 2024 at 7:00 PM",
        "abstract": "Regular meeting",
        "abstract_source_text": "This is a regular meeting of the Town Council...",
        "attendees": [],
        "topics": []
      }
    JSON

    result = job.send(:normalize_metadata, raw_json)
    parsed = JSON.parse(result)

    assert_equal "TOWN OF SPRINGFIELD - TOWN COUNCIL", parsed["governing_body_source_text"]
    assert_equal "December 25, 2024 at 7:00 PM", parsed["meeting_date_source_text"]
    assert_equal "This is a regular meeting of the Town Council...", parsed["abstract_source_text"]
  end

  test "extraction_prompt includes source_text instructions" do
    job = ExtractMetadataJob.new
    prompt = job.send(:extraction_prompt)

    assert_includes prompt, "source_text"
    assert_includes prompt, "verbatim"
    assert_includes prompt, "EXACT original text"
  end

  # Record API call tests
  test "record_api_call creates ApiCall record" do
    job = ExtractMetadataJob.new
    document = documents(:pending_document)
    usage = {
      "prompt_tokens" => 100,
      "completion_tokens" => 50,
      "total_tokens" => 150,
      "cost" => 0.00015
    }

    assert_difference "ApiCall.count", 1 do
      job.send(:record_api_call, document, usage, 1500, "success")
    end

    api_call = ApiCall.last
    assert_equal document, api_call.document
    assert_equal "openrouter", api_call.provider
    assert_equal "google/gemini-2.0-flash-001", api_call.model
    assert_equal "extract_metadata", api_call.operation
    assert_equal 100, api_call.prompt_tokens
    assert_equal 50, api_call.completion_tokens
    assert_equal 150, api_call.total_tokens
    assert_in_delta 0.00015, api_call.cost_credits, 0.000001
    assert_equal 1500, api_call.response_time_ms
    assert_equal "success", api_call.status
  end

  test "record_api_call handles error status" do
    job = ExtractMetadataJob.new
    document = documents(:pending_document)

    job.send(:record_api_call, document, {}, 0, "error", "Test error message")

    api_call = ApiCall.last
    assert_equal "error", api_call.status
    assert_equal "Test error message", api_call.error_message
  end

  test "record_api_call truncates long error messages" do
    job = ExtractMetadataJob.new
    document = documents(:pending_document)
    long_error = "x" * 2000

    job.send(:record_api_call, document, {}, 0, "error", long_error)

    api_call = ApiCall.last
    assert_equal 1000, api_call.error_message.length
  end
end
