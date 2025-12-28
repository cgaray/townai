# frozen_string_literal: true

# Links attendees from extracted document metadata to Attendee records.
# Creates new attendees when not found, or links to existing ones.
class AttendeeLinker
  attr_reader :document, :linked_count, :created_count, :errors

  def initialize(document)
    @document = document
    @linked_count = 0
    @created_count = 0
    @errors = []
  end

  # Main entry point: extracts attendees from document metadata and links them
  # Returns true on success, false on failure (check errors for details)
  def link_attendees
    unless document.complete?
      @errors << "Document is not complete (status: #{document.status})"
      return false
    end

    attendees_data = extract_attendees_from_metadata
    return true if attendees_data.empty?

    governing_body = document.metadata_field("governing_body")
    if governing_body.blank?
      @errors << "Document has no governing_body in metadata"
      return false
    end

    ActiveRecord::Base.transaction do
      # Clear existing links for this document (for re-extraction scenarios)
      document.document_attendees.destroy_all

      attendees_data.each do |attendee_data|
        link_single_attendee(attendee_data, governing_body)
      end
    end

    true
  rescue StandardError => e
    @errors << "Linking failed: #{e.message}"
    Rails.logger.error("AttendeeLinker failed for document #{document.id}: #{e.message}")
    false
  end

  def success?
    errors.empty?
  end

  private

  def extract_attendees_from_metadata
    raw = document.metadata_field("attendees")
    return [] unless raw.is_a?(Array)

    raw.select { |a| a.is_a?(Hash) && a["name"].present? }
  end

  def link_single_attendee(attendee_data, governing_body)
    name = attendee_data["name"].to_s.strip
    return if name.blank?

    normalized = Attendee.normalize_name(name)
    return if normalized.blank?

    # Find or create attendee by normalized name + governing body
    attendee = find_or_create_attendee(name, normalized, governing_body)

    # Create the document-attendee link
    create_document_attendee(attendee, attendee_data)

    # Update attendee's seen dates
    attendee.update_seen_dates!
  end

  def find_or_create_attendee(name, normalized_name, governing_body)
    # Use find_or_create_by! to handle race conditions from concurrent jobs
    # The unique index on (normalized_name, primary_governing_body) ensures uniqueness
    created = false
    attendee = Attendee.find_or_create_by!(
      normalized_name: normalized_name,
      primary_governing_body: governing_body
    ) do |a|
      a.name = name
      a.governing_bodies = [ governing_body ]
      created = true
    end

    if created
      @created_count += 1
    else
      @linked_count += 1
    end

    attendee
  rescue ActiveRecord::RecordNotUnique
    # Another process created this attendee simultaneously, retry to find it
    retry
  end

  def create_document_attendee(attendee, attendee_data)
    DocumentAttendee.create!(
      document: document,
      attendee: attendee.canonical, # Use canonical in case attendee was merged
      role: normalize_role(attendee_data["role"]),
      status: normalize_status(attendee_data["status"]),
      source_text: attendee_data["source_text"].to_s.presence
    )
  end

  def normalize_role(role)
    normalize_enum(role, DocumentAttendee::ROLES)
  end

  def normalize_status(status)
    normalize_enum(status, DocumentAttendee::STATUSES)
  end

  def normalize_enum(value, allowed_values)
    value.to_s.downcase.strip.presence.then { |v| allowed_values.include?(v) ? v : nil }
  end
end
