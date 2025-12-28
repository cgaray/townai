class ExtractMetadataJob < ApplicationJob
  queue_as :default

  MODEL = "google/gemini-2.0-flash-001"
  PROVIDER = "openrouter"

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.pending?

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    client = OpenAI::Client.new(
      access_token: Rails.application.credentials.openrouter_api_key,
      uri_base: "https://openrouter.ai/api/v1/"
    )

    pdf_base64 = nil
    document.pdf.open do |file|
      pdf_base64 = Base64.strict_encode64(file.read)
    end

    response = client.chat(
      parameters: {
        model: MODEL,
        max_tokens: 8192,
        plugins: [
          {
            id: "file-parser",
            pdf: { engine: "pdf-text" }
          }
        ],
        usage: { include: true },
        messages: [ {
          role: "user",
          content: [
            {
              type: "file",
              file: {
                filename: document.source_file_name,
                file_data: "data:application/pdf;base64,#{pdf_base64}"
              }
            },
            {
              type: "text",
              text: extraction_prompt
            }
          ]
        } ]
      }
    )

    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    response_time_ms = ((end_time - start_time) * 1000).to_i

    raw_response = response.dig("choices", 0, "message", "content")
    usage = response["usage"] || {}

    normalized = normalize_metadata(raw_response)

    if normalized
      # Record successful API call before updating document
      # This ensures accurate API tracking even if document update fails
      record_api_call(document, usage, response_time_ms, "success")

      begin
        document.update!(extracted_metadata: normalized, status: :complete)

        # Link attendees after successful extraction
        linker = AttendeeLinker.new(document)
        linker.link_attendees
        Rails.logger.info("AttendeeLinker: created=#{linker.created_count}, linked=#{linker.linked_count}")
      rescue => e
        # API call succeeded but document update failed - don't re-record as error
        document.update!(status: :failed)
        raise "Document update failed after successful API call: #{e.message}"
      end
    else
      record_api_call(document, usage, response_time_ms, "error", "Failed to parse metadata")
      document.update!(status: :failed)
      raise "Failed to parse metadata: #{raw_response.to_s.first(500)}"
    end
  rescue ActiveRecord::RecordNotFound => e
    # Document not found - no API call was made
    raise e
  rescue => e
    # Only record API error if we haven't already recorded the call
    # (i.e., error occurred before or during API call, not after)
    if !defined?(usage) || usage.empty?
      record_api_call(document, {}, response_time_ms || 0, "error", e.message) if document
    end
    document&.update!(status: :failed) if document&.persisted? && !document&.failed?
    raise e
  end

  private

  def extraction_prompt
    <<~PROMPT
      Extract metadata from this town meeting document. Return ONLY valid JSON:

      {
        "document_type": "agenda" or "minutes",
        "governing_body": "string",
        "governing_body_source_text": "verbatim text where the governing body name appears",
        "meeting_date": "YYYY-MM-DD",
        "meeting_date_source_text": "verbatim text containing the meeting date",
        "meeting_time": "HH:MM" or null,
        "abstract": "one paragraph summary of the meeting",
        "abstract_source_text": "verbatim paragraph(s) this abstract was derived from",
        "attendees": [
          {
            "name": "string",
            "role": "member|chair|clerk|staff|public",
            "status": "present|absent|remote|null",
            "source_text": "verbatim text from the attendance or roll call section mentioning this person"
          }
        ],
        "topics": [
          {
            "title": "string",
            "summary": "string",
            "action_taken": "approved|denied|tabled|continued|none",
            "source_text": "verbatim text of the full agenda item or discussion from the document"
          }
        ]
      }

      Rules:
      - Return ONLY the JSON object, no markdown, no explanation
      - Use null for unknown values
      - source_text fields must contain the EXACT original text from the document, not paraphrased
      - attendees array can be empty if not listed
      - Include as much relevant source text as possible for each item
    PROMPT
  end

  def record_api_call(document, usage, response_time_ms, status, error_message = nil)
    ApiCall.create!(
      document: document,
      provider: PROVIDER,
      model: MODEL,
      operation: "extract_metadata",
      prompt_tokens: usage["prompt_tokens"],
      completion_tokens: usage["completion_tokens"],
      total_tokens: usage["total_tokens"],
      cost_credits: usage["cost"],
      response_time_ms: response_time_ms,
      status: status,
      error_message: error_message&.first(1000)
    )
  rescue => e
    Rails.logger.error("Failed to record API call: #{e.message}")
  end

  def normalize_metadata(raw_json)
    json_str = raw_json.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip
    data = JSON.parse(json_str)

    {
      document_type: validate_enum(data["document_type"], %w[agenda minutes]),
      governing_body: data["governing_body"].to_s.presence,
      governing_body_source_text: data["governing_body_source_text"].to_s.presence,
      meeting_date: parse_date(data["meeting_date"]),
      meeting_date_source_text: data["meeting_date_source_text"].to_s.presence,
      meeting_time: data["meeting_time"],
      abstract: data["abstract"].to_s.presence,
      abstract_source_text: data["abstract_source_text"].to_s.presence,
      attendees: normalize_attendees(data["attendees"]),
      topics: normalize_topics(data["topics"])
    }.to_json
  rescue JSON::ParserError
    nil
  end

  def validate_enum(value, allowed)
    allowed.include?(value) ? value : nil
  end

  def parse_date(date_str)
    Date.parse(date_str).iso8601 if date_str
  rescue
    nil
  end

  def normalize_attendees(attendees)
    return [] unless attendees.is_a?(Array)

    attendees.map do |a|
      next unless a.is_a?(Hash)
      {
        name: a["name"].to_s.presence,
        role: validate_enum(a["role"], %w[member chair clerk staff public]),
        status: validate_enum(a["status"], %w[present absent remote]),
        source_text: a["source_text"].to_s.presence
      }.compact
    end.compact.reject(&:empty?)
  end

  def normalize_topics(topics)
    return [] unless topics.is_a?(Array)

    topics.map do |t|
      next unless t.is_a?(Hash)
      {
        title: t["title"].to_s.presence,
        summary: t["summary"].to_s.presence,
        action_taken: validate_enum(t["action_taken"], %w[approved denied tabled continued none]),
        source_text: t["source_text"].to_s.presence
      }.compact
    end.compact.reject { |t| t[:title].nil? }
  end
end
