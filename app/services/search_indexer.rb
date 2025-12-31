# frozen_string_literal: true

# SearchIndexer handles indexing content into the FTS5 search_entries table.
# Use this service to index/reindex documents, people, and governing bodies.
class SearchIndexer
  class << self
    # Rebuild the entire search index
    def rebuild_all!
      Rails.logger.info "[SearchIndexer] Starting full reindex..."

      SearchEntry.clear_all!

      index_all_governing_bodies
      index_all_people
      index_all_documents

      Rails.logger.info "[SearchIndexer] Full reindex complete"
    end

    # Index a single document (and its topics)
    def index_document(document)
      return unless document.complete?

      town = document.governing_body&.town
      return unless town # Skip indexing documents without a town

      SearchEntry.clear_entity!("document", document.id)
      SearchEntry.clear_entity!("topic", document.id) # Topics use document.id as entity_id

      # Index the document itself
      SearchEntry.insert_entry!(
        entity_type: "document",
        entity_id: document.id,
        title: document_title(document),
        subtitle: document_subtitle(document),
        content: document_content(document),
        url: document_url(document, town)
      )

      # Index each topic separately for granular search
      index_document_topics(document, town)
    end

    # Index a single person
    def index_person(person)
      SearchEntry.clear_entity!("person", person.id)

      SearchEntry.insert_entry!(
        entity_type: "person",
        entity_id: person.id,
        title: person.name,
        subtitle: person_subtitle(person),
        content: person_content(person),
        url: person_url(person)
      )
    end

    # Index a single governing body
    def index_governing_body(governing_body)
      SearchEntry.clear_entity!("governing_body", governing_body.id)

      SearchEntry.insert_entry!(
        entity_type: "governing_body",
        entity_id: governing_body.id,
        title: governing_body.name,
        subtitle: governing_body_subtitle(governing_body),
        content: governing_body_content(governing_body),
        url: governing_body_url(governing_body)
      )
    end

    # Remove a document from the index
    def remove_document(document_id)
      SearchEntry.clear_entity!("document", document_id)
      SearchEntry.clear_entity!("topic", document_id)
    end

    # Remove a person from the index
    def remove_person(person_id)
      SearchEntry.clear_entity!("person", person_id)
    end

    # Remove a governing body from the index
    def remove_governing_body(governing_body_id)
      SearchEntry.clear_entity!("governing_body", governing_body_id)
    end

    private

    def index_all_documents
      count = 0
      Document.complete.includes(governing_body: :town).find_each do |document|
        index_document(document)
        count += 1
      end
      Rails.logger.info "[SearchIndexer] Indexed #{count} documents"
    end

    def index_all_people
      count = 0
      Person.includes(:town, attendees: :governing_body).find_each do |person|
        index_person(person)
        count += 1
      end
      Rails.logger.info "[SearchIndexer] Indexed #{count} people"
    end

    def index_all_governing_bodies
      count = 0
      GoverningBody.includes(:town).find_each do |governing_body|
        index_governing_body(governing_body)
        count += 1
      end
      Rails.logger.info "[SearchIndexer] Indexed #{count} governing bodies"
    end

    def index_document_topics(document, town)
      topics = document.metadata_field("topics") || []
      return if topics.empty?

      topics.each_with_index do |topic, index|
        title = topic["title"] || topic["name"] || "Topic #{index + 1}"
        summary = topic["summary"] || topic["description"] || ""
        action = topic["action"]

        content_parts = [ summary ]
        content_parts << "Action: #{action}" if action.present?

        SearchEntry.insert_entry!(
          entity_type: "topic",
          entity_id: document.id,
          title: title,
          subtitle: "#{document_type_label(document)} - #{document.governing_body&.name || 'Unknown Body'}",
          content: content_parts.join(" "),
          url: "#{document_url(document, town)}#topic-#{index}"
        )
      end
    end

    def document_title(document)
      doc_type = document.metadata_field("document_type")
      date = document.metadata_field("meeting_date")
      body_name = document.governing_body&.name || "Unknown"

      if date.present?
        "#{body_name} #{document_type_label(document)} - #{date}"
      else
        "#{body_name} #{document_type_label(document)}"
      end
    end

    def document_subtitle(document)
      parts = []
      parts << document.governing_body&.name if document.governing_body
      parts << document.metadata_field("meeting_date")
      parts.compact.join(" - ")
    end

    def document_content(document)
      parts = []

      # Add raw text (truncated for reasonable index size)
      if document.raw_text.present?
        parts << document.raw_text.truncate(10000)
      end

      # Add topic titles and summaries
      topics = document.metadata_field("topics") || []
      topics.each do |topic|
        parts << topic["title"] if topic["title"]
        parts << topic["summary"] if topic["summary"]
      end

      # Add attendee names
      attendees = document.metadata_field("attendees") || []
      attendees.each do |attendee|
        parts << attendee["name"] if attendee["name"]
        parts << attendee["role"] if attendee["role"]
      end

      parts.join(" ")
    end

    def document_type_label(document)
      case document.metadata_field("document_type")&.downcase
      when "agenda" then "Agenda"
      when "minutes" then "Minutes"
      else "Document"
      end
    end

    def person_subtitle(person)
      body = person.primary_governing_body
      roles = person.roles_held.first(3)

      parts = []
      parts << body.name if body
      parts << roles.join(", ") if roles.any?
      parts.join(" - ").presence || "Community Member"
    end

    def person_content(person)
      parts = [ person.name ]

      # Add all roles
      parts.concat(person.roles_held)

      # Add governing body associations
      person.attendees.includes(:governing_body).each do |attendee|
        parts << attendee.governing_body&.name
        parts << attendee.name if attendee.name != person.name
      end

      parts.compact.uniq.join(" ")
    end

    def governing_body_subtitle(governing_body)
      doc_count = governing_body.documents.complete.count
      "#{doc_count} #{'document'.pluralize(doc_count)}"
    end

    def governing_body_content(governing_body)
      parts = [ governing_body.name ]

      # Add member names
      governing_body.attendees.includes(:person).each do |attendee|
        parts << attendee.person&.name
        parts << attendee.name
      end

      parts.compact.uniq.join(" ")
    end

    # URL helpers for town-scoped resources
    def document_url(document, town)
      url_helpers.town_document_path(town, document)
    end

    def person_url(person)
      url_helpers.town_person_path(person.town, person)
    end

    def governing_body_url(governing_body)
      url_helpers.town_governing_body_path(governing_body.town, governing_body)
    end

    def url_helpers
      Rails.application.routes.url_helpers
    end
  end
end
