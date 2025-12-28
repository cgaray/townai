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
        puts "[#{index + 1}/#{total}] Document #{document.id}: skipped (no governing body or attendees)"
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
    puts "  Active attendees: #{Attendee.active.count}"
  end

  desc "Show attendee statistics"
  task stats: :environment do
    puts "Attendee Statistics"
    puts "==================="
    puts "Total attendees: #{Attendee.count}"
    puts "Active attendees: #{Attendee.active.count}"
    puts "Merged attendees: #{Attendee.merged.count}"
    puts "Document-attendee links: #{DocumentAttendee.count}"
    puts ""
    puts "By governing body:"
    Attendee.active.group(:primary_governing_body).count.sort_by { |_, v| -v }.each do |body, count|
      puts "  #{body}: #{count}"
    end
    puts ""
    puts "Top 10 by appearances:"
    Attendee.active.by_appearances.limit(10).each do |attendee|
      puts "  #{attendee.name} (#{attendee.primary_governing_body}): #{attendee.document_appearances_count} docs"
    end
  end

  desc "Find potential duplicate attendees"
  task find_duplicates: :environment do
    puts "Potential Duplicate Attendees"
    puts "=============================="

    duplicates_found = 0

    Attendee.active.find_each do |attendee|
      potential = attendee.potential_duplicates
      same_name = potential[:same_name_different_body]
      similar_name = potential[:similar_name]

      next if same_name.empty? && similar_name.empty?

      duplicates_found += 1
      puts "\n#{attendee.name} (#{attendee.primary_governing_body}, ID: #{attendee.id})"

      if same_name.any?
        puts "  Same name, different body:"
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

    puts "\nTotal attendees with potential duplicates: #{duplicates_found}"
  end
end
