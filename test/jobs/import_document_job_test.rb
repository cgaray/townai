require "test_helper"

class ImportDocumentJobTest < ActiveJob::TestCase
  setup do
    @test_pdf_path = Rails.root.join("test/fixtures/files/test_document.pdf")
    # Create a minimal test PDF if it doesn't exist
    FileUtils.mkdir_p(File.dirname(@test_pdf_path))
    unless File.exist?(@test_pdf_path)
      File.write(@test_pdf_path, "%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>")
    end
  end

  test "creates new document from file" do
    assert_difference "Document.count", 1 do
      ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    end
  end

  test "sets source_file_name from file path" do
    ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    doc = Document.last
    assert_equal "test_document.pdf", doc.source_file_name
  end

  test "sets source_file_hash from file content" do
    ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    doc = Document.last
    expected_hash = Digest::SHA256.file(@test_pdf_path).hexdigest
    assert_equal expected_hash, doc.source_file_hash
  end

  test "sets status to pending" do
    ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    doc = Document.last
    assert doc.pending?
  end

  test "attaches pdf to document" do
    ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    doc = Document.last
    assert doc.pdf.attached?
  end

  test "enqueues ExtractMetadataJob" do
    assert_enqueued_with(job: ExtractMetadataJob) do
      ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    end
  end

  test "skips duplicate file based on hash" do
    # First import
    ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    initial_count = Document.count

    # Second import of same file should be skipped
    assert_no_difference "Document.count" do
      ImportDocumentJob.perform_now(@test_pdf_path.to_s)
    end
  end

  test "allows different files with different hashes" do
    ImportDocumentJob.perform_now(@test_pdf_path.to_s)

    # Create a different test file
    different_pdf_path = Rails.root.join("test/fixtures/files/different_document.pdf")
    File.write(different_pdf_path, "%PDF-1.4\n1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj\ntrailer<</Root 1 0 R>>")

    assert_difference "Document.count", 1 do
      ImportDocumentJob.perform_now(different_pdf_path.to_s)
    end
  ensure
    FileUtils.rm_f(different_pdf_path) if defined?(different_pdf_path)
  end
end
