# frozen_string_literal: true

require "pdf-reader"

# Extracts text from PDF documents for LLM metadata extraction.
#
# Strategy:
# 1. If PDF has an outline with "Meeting Agenda" or "Meeting Minutes" bookmark,
#    extract only that section (stopping before attachments)
# 2. Otherwise, extract first N pages
#
class PdfSectionExtractor
  MAX_PAGES = 25

  attr_reader :reader

  def initialize(path)
    @reader = PDF::Reader.new(path)
  end

  def page_count
    reader.page_count
  end

  # Extract text from the primary content (agenda/minutes section or first N pages)
  def extract_primary_text
    result = find_primary_content
    extract_text_from_pages(result[:start_page], result[:end_page])
  end

  # Returns info about what was extracted
  def analyze
    result = find_primary_content
    {
      total_pages: reader.page_count,
      primary_content: {
        start_page: result[:start_page],
        end_page: result[:end_page],
        page_count: result[:end_page] - result[:start_page] + 1
      },
      has_attachments: result[:end_page] < reader.page_count,
      detection_method: result[:detection_method]
    }
  end

  # Extract text from specific page range
  def extract_text_from_pages(start_page, end_page)
    text_parts = []

    (start_page..end_page).each do |page_num|
      next if page_num > reader.page_count || page_num < 1

      begin
        page = reader.pages[page_num - 1]
        text_parts << page.text.to_s
      rescue StandardError => e
        Rails.logger.warn("Failed to extract text from page #{page_num}: #{e.message}")
      end
    end

    text_parts.join("\n\n--- Page Break ---\n\n")
  end

  private

  def find_primary_content
    @primary_content ||= detect_primary_content
  end

  def detect_primary_content
    # Try outline detection first
    outline_result = detect_from_outline
    return outline_result if outline_result

    # Fallback: first N pages
    {
      start_page: 1,
      end_page: [ reader.page_count, MAX_PAGES ].min,
      detection_method: :page_limit
    }
  end

  # Try to detect primary content boundaries from PDF outline/bookmarks
  def detect_from_outline
    sections = extract_outline_sections
    return nil if sections.empty?

    # Find "Meeting Agenda" or "Meeting Minutes" section
    primary_idx = sections.index { |s| s[:title] =~ /Meeting\s*(Agenda|Minutes)/i }
    return nil unless primary_idx

    primary_section = sections[primary_idx]
    next_section = sections[primary_idx + 1]

    # End page is one before the next section, or MAX_PAGES, whichever is smaller
    end_page = if next_section && next_section[:page]
                 [ next_section[:page] - 1, MAX_PAGES ].min
    else
                 [ reader.page_count, MAX_PAGES ].min
    end

    {
      start_page: primary_section[:page] || 1,
      end_page: [ end_page, reader.page_count ].min,
      detection_method: :outline
    }
  end

  # Extract top-level outline sections with their page numbers
  def extract_outline_sections
    @outline_sections ||= build_outline_sections
  end

  def build_outline_sections
    page_id_to_num = build_page_id_map
    outlines_ref = find_outlines_root
    return [] unless outlines_ref

    sections = []
    walk_outline_items(outlines_ref, page_id_to_num, sections)
    sections
  end

  def find_outlines_root
    root = reader.objects[reader.objects.trailer[:Root]]
    return nil unless root.is_a?(Hash) && root[:Outlines]

    outlines = reader.objects[root[:Outlines]]
    return nil unless outlines.is_a?(Hash) && outlines[:First]

    outlines[:First]
  end

  # Walk sibling outline items via Next pointers (top-level only)
  def walk_outline_items(ref, page_id_to_num, sections, depth: 0)
    return unless ref.is_a?(PDF::Reader::Reference)
    return if depth > 50 # Prevent infinite loops

    obj = reader.objects[ref]
    return unless obj.is_a?(Hash)

    if obj[:Title]
      page_num = extract_page_from_dest(obj[:Dest], page_id_to_num)
      sections << { title: obj[:Title].to_s, page: page_num }
    end

    # Follow Next sibling
    walk_outline_items(obj[:Next], page_id_to_num, sections, depth: depth + 1) if obj[:Next]
  end

  def extract_page_from_dest(dest, page_id_to_num)
    return nil unless dest.is_a?(Array) && dest.first.is_a?(PDF::Reader::Reference)
    page_id_to_num[dest.first.id]
  end

  # Build mapping from page object IDs to page numbers
  def build_page_id_map
    page_id_to_num = {}
    page_ref_ids = []

    reader.objects.each do |ref, obj|
      page_ref_ids << ref.id if obj.is_a?(Hash) && obj[:Type] == :Page
    end

    page_ref_ids.sort.each_with_index do |ref_id, idx|
      page_id_to_num[ref_id] = idx + 1
    end

    page_id_to_num
  end
end
