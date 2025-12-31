# frozen_string_literal: true

namespace :governing_bodies do
  desc "Backfill governing_body_id from existing data for a specific town"
  task :backfill, [ :town_slug ] => :environment do |_t, args|
    if args[:town_slug].blank?
      puts "Usage: bin/rails governing_bodies:backfill[TOWN_SLUG]"
      puts "Example: bin/rails governing_bodies:backfill[brookline]"
      puts ""
      puts "Available towns:"
      Town.order(:name).each { |t| puts "  - #{t.slug} (#{t.name})" }
      exit 1
    end

    town = Town.find_by(slug: args[:town_slug])
    unless town
      puts "Error: Town '#{args[:town_slug]}' not found."
      puts ""
      puts "Available towns:"
      Town.order(:name).each { |t| puts "  - #{t.slug} (#{t.name})" }
      exit 1
    end

    puts "Backfilling GoverningBody records for #{town.name}..."

    # From Documents - only process documents that belong to this town's governing bodies
    # or documents without a governing body that we'll assign to this town
    doc_count = 0
    town.documents.where(governing_body_id: nil).find_each do |doc|
      name = doc.metadata_field("governing_body")
      next if name.blank?

      gb = GoverningBody.find_or_create_by_name(name, town: town)
      doc.update!(governing_body: gb)
      doc_count += 1
    end
    puts "  Updated #{doc_count} documents"

    # From Attendees - only process attendees linked to this town's governing bodies
    attendee_count = 0
    Attendee.joins(:governing_body)
            .where(governing_bodies: { town_id: town.id })
            .where(governing_body_id: nil)
            .find_each do |attendee|
      name = attendee.governing_body_extracted
      next if name.blank?

      gb = GoverningBody.find_or_create_by_name(name, town: town)
      attendee.update!(governing_body_id: gb.id)
      attendee_count += 1
    end
    puts "  Updated #{attendee_count} attendees"

    # Update counter caches
    puts "Updating counter caches..."
    GoverningBody.where(town: town).find_each do |gb|
      GoverningBody.reset_counters(gb.id, :documents)
    end

    puts "Done! #{town.name} has #{town.governing_bodies.count} governing bodies."
    town.governing_bodies.by_document_count.each do |gb|
      puts "  #{gb.name}: #{gb.documents_count} documents"
    end
  end
end
