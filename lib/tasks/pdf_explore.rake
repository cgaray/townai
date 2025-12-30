# frozen_string_literal: true

require "pdf-reader"

namespace :pdf do
  desc "Explore PDF structure - shows pages, sections, and text samples"
  task :explore, [ :path ] => :environment do |_t, args|
    path = args[:path]
    abort "Usage: rake pdf:explore[path/to/file.pdf]" unless path
    abort "File not found: #{path}" unless File.exist?(path)

    reader = PDF::Reader.new(path)

    puts "=" * 80
    puts "PDF: #{path}"
    puts "Pages: #{reader.page_count}"
    puts "=" * 80

    # Track potential section headers
    sections = []

    reader.pages.each_with_index do |page, idx|
      page_num = idx + 1
      text = page.text.to_s

      puts "\n#{'─' * 80}"
      puts "PAGE #{page_num}"
      puts "─" * 80

      # Get first 500 chars to see what's on this page
      preview = text.strip.gsub(/\s+/, " ").first(500)
      puts "Preview: #{preview}..."

      # Look for potential section headers (lines that look like titles)
      lines = text.lines.map(&:strip).reject(&:empty?)
      potential_headers = lines.first(10).select do |line|
        # Likely a header if: short, possibly all caps, no punctuation at end
        line.length < 100 &&
          line.length > 3 &&
          !line.end_with?(".", ",", ";") &&
          !line.match?(/^\d+\.\d+/) # not a number like "1.5"
      end

      if potential_headers.any?
        puts "\nPotential headers on this page:"
        potential_headers.first(5).each { |h| puts "  - #{h}" }
      end

      # Detect if this might be a section boundary
      first_line = lines.first.to_s
      if first_line.match?(/^(meeting\s+)?(agenda|minutes|attachments?|appendix|exhibit)/i) ||
         first_line.match?(/^\d+\s+[A-Z]/) # numbered section like "47 Spy Pond Lane"
        sections << { page: page_num, title: first_line }
      end
    end

    puts "\n#{'=' * 80}"
    puts "DETECTED SECTIONS"
    puts "=" * 80
    if sections.any?
      sections.each do |s|
        puts "  Page #{s[:page]}: #{s[:title]}"
      end
    else
      puts "  No clear section boundaries detected"
    end
  end

  desc "Quick summary of PDF - just page count and first page content"
  task :summary, [ :path ] => :environment do |_t, args|
    path = args[:path]
    abort "Usage: rake pdf:summary[path/to/file.pdf]" unless path
    abort "File not found: #{path}" unless File.exist?(path)

    reader = PDF::Reader.new(path)

    puts "PDF: #{path}"
    puts "Pages: #{reader.page_count}"
    puts "File size: #{(File.size(path) / 1024.0).round(1)} KB"
    puts "\nFirst page text:"
    puts "-" * 40
    puts reader.pages.first.text.to_s.first(2000)
  end

  desc "Explore all sample PDFs"
  task explore_samples: :environment do
    Dir.glob("tmp/samples/**/*.pdf").reject { |f| f.include?("_text.pdf") }.each do |pdf|
      Rake::Task["pdf:summary"].reenable
      Rake::Task["pdf:summary"].invoke(pdf)
      puts "\n#{'=' * 80}\n\n"
    end
  end
end
