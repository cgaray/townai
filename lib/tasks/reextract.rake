namespace :documents do
  desc "Re-extract metadata with source text for all documents"
  task reextract: :environment do
    documents = Document.where.not(status: :failed)
    total = documents.count

    puts "Re-extracting metadata for #{total} documents..."

    documents.find_each.with_index do |doc, index|
      puts "[#{index + 1}/#{total}] Processing: #{doc.source_file_name}"

      doc.update!(status: :pending, extracted_metadata: nil)
      ExtractMetadataJob.perform_later(doc.id)
    end

    puts "Done! #{total} documents queued for re-extraction."
    puts "Run 'bin/jobs' to process the queue."
  end

  desc "Re-extract metadata for a single document by ID"
  task :reextract_one, [ :id ] => :environment do |_t, args|
    doc = Document.find(args[:id])
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
