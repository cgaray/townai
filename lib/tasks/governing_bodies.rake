# frozen_string_literal: true

namespace :governing_bodies do
  desc "Backfill governing_body_id from existing data"
  task backfill: :environment do
    puts "Backfilling GoverningBody records..."

    # From Documents (extracted metadata)
    doc_count = 0
    Document.where(governing_body_id: nil).find_each do |doc|
      name = doc.metadata_field("governing_body")
      next if name.blank?

      gb = GoverningBody.find_or_create_by_name(name)
      doc.update_column(:governing_body_id, gb.id)
      doc_count += 1
    end
    puts "  Updated #{doc_count} documents"

    # From Attendees (governing_body_extracted string column)
    attendee_count = 0
    Attendee.where(governing_body_id: nil).find_each do |attendee|
      name = attendee.governing_body_extracted
      next if name.blank?

      gb = GoverningBody.find_or_create_by_name(name)
      attendee.update!(governing_body_id: gb.id)
      attendee_count += 1
    end
    puts "  Updated #{attendee_count} attendees"

    # Update counter caches
    puts "Updating counter caches..."
    GoverningBody.find_each do |gb|
      GoverningBody.reset_counters(gb.id, :documents)
    end

    puts "Done! Created #{GoverningBody.count} governing bodies."
    GoverningBody.by_document_count.each do |gb|
      puts "  #{gb.name}: #{gb.documents_count} documents"
    end
  end
end
