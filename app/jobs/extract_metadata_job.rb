class ExtractMetadataJob < ApplicationJob
  queue_as :default

  def perform(document_id)
    document = Document.find(document_id)
    return unless document.pending?

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
        model: "google/gemini-2.0-flash-001",
        max_tokens: 4096,
        plugins: [
          {
            id: "file-parser",
            pdf: { engine: "pdf-text" }
          }
        ],
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
              text: <<~PROMPT
                Extract metadata from this town meeting document. Return ONLY valid JSON:

                {
                  "document_type": "agenda" or "minutes",
                  "governing_body": "string",
                  "meeting_date": "YYYY-MM-DD",
                  "meeting_time": "HH:MM" or null,
                  "abstract": "string",
                  "attendees": [
                    {"name": "string", "role": "member|chair|clerk|staff|public", "status": "present|absent|remote|null"}
                  ],
                  "topics": [
                    {"title": "string", "summary": "string", "action_taken": "approved|denied|tabled|continued|none"}
                  ]
                }

                Rules:
                - Return ONLY the JSON object, no markdown, no explanation
                - Use null for unknown values
                - attendees array can be empty if not listed
              PROMPT
            }
          ]
        } ]
      }
    )

    raw_response = response.dig("choices", 0, "message", "content")
    normalized = normalize_metadata(raw_response)

    if normalized
      document.update!(extracted_metadata: normalized, status: :complete)
    else
      document.update!(status: :failed)
      raise "Failed to parse metadata: #{raw_response.first(500)}"
    end
  rescue => e
    document.update!(status: :failed)
    raise e
  end

  private

  def normalize_metadata(raw_json)
    json_str = raw_json.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip
    data = JSON.parse(json_str)

    {
      document_type: validate_enum(data["document_type"], %w[agenda minutes]),
      governing_body: data["governing_body"].to_s.presence,
      meeting_date: parse_date(data["meeting_date"]),
      meeting_time: data["meeting_time"],
      abstract: data["abstract"].to_s.presence,
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
        status: validate_enum(a["status"], %w[present absent remote])
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
        action_taken: validate_enum(t["action_taken"], %w[approved denied tabled continued none])
      }.compact
    end.compact.reject { |t| t[:title].nil? }
  end
end
