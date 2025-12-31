class ImportDocumentJob < ApplicationJob
  queue_as :default

  def perform(file_path, town_id = nil)
    hash = Digest::SHA256.file(file_path).hexdigest
    return if Document.exists?(source_file_hash: hash)

    doc = Document.create!(
      source_file_name: File.basename(file_path),
      source_file_hash: hash,
      status: :pending
    )
    doc.pdf.attach(io: File.open(file_path), filename: File.basename(file_path))

    ExtractMetadataJob.perform_later(doc.id, town_id)
  end
end
