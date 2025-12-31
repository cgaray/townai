# frozen_string_literal: true

# Background job for reindexing search entries.
# This avoids blocking the main request thread during saves.
class ReindexSearchJob < ApplicationJob
  queue_as :default

  def perform(entity_type, entity_id)
    case entity_type
    when "document"
      document = Document.find_by(id: entity_id)
      SearchIndexer.index_document(document) if document
    when "person"
      person = Person.find_by(id: entity_id)
      SearchIndexer.index_person(person) if person
    when "governing_body"
      governing_body = GoverningBody.find_by(id: entity_id)
      SearchIndexer.index_governing_body(governing_body) if governing_body
    end
  end
end
