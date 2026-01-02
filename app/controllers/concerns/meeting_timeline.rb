# frozen_string_literal: true

module MeetingTimeline
  extend ActiveSupport::Concern

  private

  # Builds a hierarchical timeline: year → month → day → meetings
  # Groups documents by governing body within each day to combine agenda + minutes
  # Each meeting item has:
  #   - :documents - array of documents for this meeting (agenda, minutes, etc.)
  #   - :governing_body - the governing body name
  #   - :extras - hash of extra data keyed by document_id
  #   - :topics - deduplicated topics from all documents
  def build_meetings_hierarchy(documents, extra_data_by_doc_id = {})
    hierarchy = {}

    # First, group documents by date and governing body
    meetings_by_key = {}

    documents.each do |doc|
      date = parse_meeting_date(doc.metadata_field("meeting_date"))
      next unless date

      governing_body_id = doc.governing_body_id
      governing_body_name = doc.metadata_field("governing_body") || doc.governing_body&.name

      # Key by date + governing body to group agenda and minutes together
      key = [ date, governing_body_id ]
      meetings_by_key[key] ||= {
        date: date,
        governing_body: governing_body_name,
        governing_body_id: governing_body_id,
        documents: [],
        extras: {}
      }

      meetings_by_key[key][:documents] << doc
      if (extra = extra_data_by_doc_id[doc.id])
        meetings_by_key[key][:extras][doc.id] = extra
      end
    end

    # Now build hierarchy from grouped meetings
    meetings_by_key.each_value do |meeting|
      date = meeting[:date]
      year = date.year
      month = date.month
      day = date.day

      hierarchy[year] ||= { months: {}, count: 0 }
      hierarchy[year][:months][month] ||= { name: Date::MONTHNAMES[month], days: {} }
      hierarchy[year][:months][month][:days][day] ||= []

      # Sort documents: minutes first (has final actions), then agenda
      meeting[:documents].sort_by! do |doc|
        doc_type = doc.metadata_field("document_type")&.downcase
        doc_type == "minutes" ? 0 : 1
      end

      # Merge topics from all documents, preferring minutes (has final actions)
      meeting[:topics] = merge_meeting_topics(meeting[:documents], meeting[:extras])

      hierarchy[year][:months][month][:days][day] << meeting
      hierarchy[year][:count] += 1
    end

    # Sort: years descending, months descending, days descending
    hierarchy.sort.reverse.to_h.transform_values do |year_data|
      year_data[:months] = year_data[:months].sort.reverse.to_h.transform_values do |month_data|
        month_data[:days] = month_data[:days].sort.reverse.to_h
        month_data
      end
      year_data
    end
  end

  # Merge topics from multiple documents (agenda + minutes)
  # Deduplicates by normalized title, preferring minutes version (has final action)
  def merge_meeting_topics(documents, extras)
    topics_by_title = {}

    documents.each do |doc|
      doc_type = doc.metadata_field("document_type")&.downcase
      is_minutes = doc_type == "minutes"

      # Get topics from extras if available (preloaded), otherwise from document
      topics = extras.dig(doc.id, :topics) || doc.topics.ordered

      topics.each do |topic|
        normalized_title = topic.title.downcase.strip
        existing = topics_by_title[normalized_title]

        # Keep this topic if:
        # 1. No existing topic with this title, or
        # 2. This is from minutes and existing is not (prefer final actions over agenda)
        if existing.nil? || (is_minutes && existing[:doc_type] != "minutes")
          topics_by_title[normalized_title] = {
            topic: topic,
            document: doc,
            doc_type: doc_type
          }
        end
      end
    end

    # Return topics sorted by position, with document reference for linking
    topics_by_title.values.sort_by { |t| t[:topic].position || 0 }
  end

  def parse_meeting_date(date_str)
    return nil if date_str.blank?
    Date.parse(date_str)
  rescue ArgumentError
    nil
  end
end
