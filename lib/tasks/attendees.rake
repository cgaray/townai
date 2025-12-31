# frozen_string_literal: true

namespace :attendees do
  desc "Link attendees from complete documents for a specific town"
  task :link_existing, [ :town_slug ] => :environment do |_t, args|
    if args[:town_slug].blank?
      puts "Usage: bin/rails attendees:link_existing[TOWN_SLUG]"
      puts "Example: bin/rails attendees:link_existing[arlington]"
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

    puts "Linking attendees from existing documents for #{town.name}..."

    documents = town.documents.complete.where.not(extracted_metadata: nil)
    total = documents.count
    linked = 0
    skipped = 0
    errors = 0

    documents.find_each.with_index do |document, index|
      linker = AttendeeLinker.new(document, town: town)

      if linker.link_attendees
        linked += 1
        puts "[#{index + 1}/#{total}] Document #{document.id}: created=#{linker.created_count}, linked=#{linker.linked_count}"
      else
        skipped += 1
        puts "[#{index + 1}/#{total}] Document #{document.id}: skipped (#{linker.errors.join(', ')})"
      end
    rescue StandardError => e
      errors += 1
      puts "[#{index + 1}/#{total}] Document #{document.id}: ERROR - #{e.message}"
    end

    puts "\nCompleted!"
    puts "  Total documents: #{total}"
    puts "  Successfully processed: #{linked}"
    puts "  Skipped: #{skipped}"
    puts "  Errors: #{errors}"
    puts "  Total attendees in #{town.name}: #{Attendee.joins(:governing_body).where(governing_bodies: { town_id: town.id }).count}"
    puts "  Total people in #{town.name}: #{town.people.count}"
  end

  desc "Show attendee and people statistics"
  task :stats, [ :town_slug ] => :environment do |_t, args|
    if args[:town_slug].present?
      town = Town.find_by(slug: args[:town_slug])
      unless town
        puts "Error: Town '#{args[:town_slug]}' not found."
        puts "Available towns:"
        Town.order(:name).each { |t| puts "  - #{t.slug} (#{t.name})" }
        exit 1
      end

      puts "People & Attendee Statistics for #{town.name}"
      puts "=" * 50
      puts "Total people: #{town.people.count}"
      puts "Total attendees (raw extractions): #{Attendee.joins(:governing_body).where(governing_bodies: { town_id: town.id }).count}"
      puts "Document-attendee links: #{DocumentAttendee.joins(document: :governing_body).where(governing_bodies: { town_id: town.id }).count}"
      puts ""
      puts "By governing body:"
      town.governing_bodies.includes(:attendees).each do |gb|
        puts "  #{gb.name}: #{gb.attendees.count} attendees"
      end
      puts ""
      puts "Top 10 people by appearances:"
      town.people.by_appearances.limit(10).each do |person|
        puts "  #{person.name} (#{person.primary_governing_body&.name}): #{person.document_appearances_count} docs"
      end
    else
      puts "People & Attendee Statistics (All Towns)"
      puts "=" * 50
      puts "Total people: #{Person.count}"
      puts "Total attendees (raw extractions): #{Attendee.count}"
      puts "Document-attendee links: #{DocumentAttendee.count}"
      puts ""

      Town.order(:name).each do |town|
        puts "#{town.name}:"
        puts "  People: #{town.people.count}"
        puts "  Governing bodies: #{town.governing_bodies.count}"
        puts "  Documents: #{town.documents.count}"
        puts ""
      end

    end
  end

  desc "Find potential duplicate people"
  task find_duplicates: :environment do
    puts "Potential Duplicate People"
    puts "=========================="

    duplicates_found = 0

    Person.find_each do |person|
      potential = person.potential_duplicates
      same_name = potential[:same_name_different_body]
      similar_name = potential[:similar_name]

      next if same_name.empty? && similar_name.empty?

      duplicates_found += 1
      puts "\n#{person.name} (#{person.primary_governing_body}, ID: #{person.id})"

      if same_name.any?
        puts "  Same name:"
        same_name.each do |dup|
          puts "    - #{dup.name} (#{dup.primary_governing_body}, ID: #{dup.id})"
        end
      end

      if similar_name.any?
        puts "  Similar names:"
        similar_name.each do |dup|
          puts "    - #{dup.name} (#{dup.primary_governing_body}, ID: #{dup.id})"
        end
      end
    end

    puts "\nTotal people with potential duplicates: #{duplicates_found}"
  end
end
