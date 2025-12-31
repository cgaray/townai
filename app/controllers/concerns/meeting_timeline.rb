# frozen_string_literal: true

module MeetingTimeline
  extend ActiveSupport::Concern

  private

  # Builds a hierarchical timeline: year → month → day → items
  # Each item is a hash with :document and optional :extra data (e.g., role, status)
  def build_meetings_hierarchy(documents, extra_data_by_doc_id = {})
    hierarchy = {}

    documents.each do |doc|
      date = parse_meeting_date(doc.metadata_field("meeting_date"))
      next unless date

      year = date.year
      month = date.month
      day = date.day

      hierarchy[year] ||= { months: {}, count: 0 }
      hierarchy[year][:months][month] ||= { name: Date::MONTHNAMES[month], days: {} }
      hierarchy[year][:months][month][:days][day] ||= []

      item = { document: doc }
      if (extra = extra_data_by_doc_id[doc.id])
        item[:extra] = extra
      end

      hierarchy[year][:months][month][:days][day] << item
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

  def parse_meeting_date(date_str)
    return nil if date_str.blank?
    Date.parse(date_str)
  rescue ArgumentError
    nil
  end
end
