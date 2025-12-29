# frozen_string_literal: true

namespace :attendees do
  desc "Link attendees from all existing complete documents"
  task link_existing: :environment do
    puts "Linking attendees from existing documents..."

    documents = Document.complete.where.not(extracted_metadata: nil)
    total = documents.count
    linked = 0
    skipped = 0
    errors = 0

    documents.find_each.with_index do |document, index|
      linker = AttendeeLinker.new(document)

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
    puts "  Total attendees: #{Attendee.count}"
    puts "  Total people: #{Person.count}"
  end

  desc "Show attendee and people statistics"
  task stats: :environment do
    puts "People & Attendee Statistics"
    puts "============================"
    puts "Total people: #{Person.count}"
    puts "Total attendees (raw extractions): #{Attendee.count}"
    puts "Document-attendee links: #{DocumentAttendee.count}"
    puts ""
    puts "By governing body:"
    Attendee.group(:governing_body).count.sort_by { |_, v| -v }.each do |body, count|
      puts "  #{body}: #{count}"
    end
    puts ""
    puts "Top 10 people by appearances:"
    Person.by_appearances.limit(10).each do |person|
      puts "  #{person.name} (#{person.primary_governing_body}): #{person.document_appearances_count} docs"
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
