# frozen_string_literal: true

# Links attendees from extracted document metadata to Attendee records.
# Creates new attendees (and their Person) when not found, or links to existing ones.
# Updates the Person's document_appearances_count after linking.
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

    affected_people = Set.new

    ActiveRecord::Base.transaction do
      # Clear existing links for this document (for re-extraction scenarios)
      # Track affected people before clearing
      document.document_attendees.includes(attendee: :person).each do |da|
        affected_people << da.attendee.person if da.attendee.person
      end
      document.document_attendees.destroy_all

      attendees_data.each do |attendee_data|
        attendee = link_single_attendee(attendee_data, governing_body)
        affected_people << attendee.person if attendee&.person
      end

      # Update counter caches for all affected people
      affected_people.each(&:update_appearances_count!)
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

    valid = raw.select { |a| a.is_a?(Hash) && a["name"].present? }

    # Deduplicate by normalized name, keeping the entry with the most useful status
    # Priority: present > remote > absent > nil
    deduplicated = {}
    valid.each do |attendee_data|
      name = attendee_data["name"].to_s.strip
      normalized = Attendee.normalize_name(name)
      next if normalized.blank?

      existing = deduplicated[normalized]
      if existing.nil? || status_priority(attendee_data["status"]) > status_priority(existing["status"])
        deduplicated[normalized] = attendee_data
      end
    end

    deduplicated.values
  end

  # Higher number = higher priority when deduplicating
  def status_priority(status)
    case status.to_s.downcase
    when "present" then 3
    when "remote" then 2
    when "absent" then 1
    else 0
    end
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

    attendee
  end

  def find_or_create_attendee(name, normalized_name, governing_body)
    # Use find_or_create_by! to handle race conditions from concurrent jobs
    # The unique index on (normalized_name, governing_body) ensures uniqueness
    created = false
    attendee = Attendee.find_or_create_by!(
      normalized_name: normalized_name,
      governing_body: governing_body
    ) do |a|
      a.name = name
      # Create a new Person for this new attendee
      a.person = Person.create!(name: name, normalized_name: normalized_name)
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
      attendee: attendee,
      role: normalize_role(attendee_data["role"]),
      status: normalize_status(attendee_data["status"]),
      source_text: attendee_data["source_text"].to_s.presence
    )
  end

  def normalize_role(role)
    # Role is free-form - just clean up whitespace, preserve original casing
    role.to_s.strip.presence
  end

  def normalize_status(status)
    # Status is validated enum - normalize to lowercase
    normalized = status.to_s.downcase.strip.presence
    DocumentAttendee::STATUSES.include?(normalized) ? normalized : nil
  end
end
