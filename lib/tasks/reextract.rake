namespace :documents do
  desc "Re-extract metadata with source text for all completed documents"
  task reextract: :environment do
    # Only re-extract completed documents, skip failed and in-progress ones
    documents = Document.where(status: :complete)
    total = documents.count

    if total == 0
      puts "No completed documents found to re-extract."
      exit
    end

    puts "Re-extracting metadata for #{total} completed documents..."
    puts "(Skipping failed and in-progress documents)"

    documents.find_each.with_index do |doc, index|
      puts "[#{index + 1}/#{total}] Queuing: #{doc.source_file_name}"

      doc.update!(status: :pending, extracted_metadata: nil)
      ExtractMetadataJob.perform_later(doc.id)
    end

    puts "Done! #{total} documents queued for re-extraction."
    puts "Run 'bin/jobs' to process the queue."
  end

  desc "Re-extract metadata for a single document by ID"
  task :reextract_one, [ :id ] => :environment do |_t, args|
    if args[:id].blank?
      puts "Error: Document ID is required."
      puts "Usage: bin/rails documents:reextract_one[ID]"
      puts "Example: bin/rails documents:reextract_one[123]"
      exit 1
    end

    doc = Document.find(args[:id])

    if doc.extracting_text? || doc.extracting_metadata?
      puts "Error: Document is currently being processed (status: #{doc.status})."
      puts "Please wait for processing to complete before retrying."
      exit 1
    end

    puts "Re-extracting metadata for: #{doc.source_file_name}"

    doc.update!(status: :pending, extracted_metadata: nil)
    ExtractMetadataJob.perform_now(doc.id)

    doc.reload
    if doc.complete?
      puts "Success! Document status: #{doc.status}"
    else
      puts "Failed! Document status: #{doc.status}"
    end
  end
end
