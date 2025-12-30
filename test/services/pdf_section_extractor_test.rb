# frozen_string_literal: true

require "test_helper"

class PdfSectionExtractorTest < ActiveSupport::TestCase
  test "extracts primary text from sample PDF" do
    pdf_path = Rails.root.join("test/fixtures/files/sample.pdf")
    skip "Sample PDF not found" unless File.exist?(pdf_path)

    extractor = PdfSectionExtractor.new(pdf_path)
    text = extractor.extract_primary_text

    assert text.present?, "Should extract some text"
  end

  test "analyze returns expected structure" do
    pdf_path = Rails.root.join("test/fixtures/files/sample.pdf")
    skip "Sample PDF not found" unless File.exist?(pdf_path)

    extractor = PdfSectionExtractor.new(pdf_path)
    analysis = extractor.analyze

    assert analysis.key?(:total_pages)
    assert analysis.key?(:primary_content)
    assert analysis.key?(:has_attachments)
    assert analysis.key?(:detection_method)

    assert analysis[:primary_content].key?(:start_page)
    assert analysis[:primary_content].key?(:end_page)
    assert analysis[:primary_content].key?(:page_count)

    assert_includes [ :page_limit, :outline ], analysis[:detection_method]
  end

  test "extract_text_from_pages returns text for valid range" do
    pdf_path = Rails.root.join("test/fixtures/files/sample.pdf")
    skip "Sample PDF not found" unless File.exist?(pdf_path)

    extractor = PdfSectionExtractor.new(pdf_path)
    text = extractor.extract_text_from_pages(1, 1)

    assert text.is_a?(String)
  end

  test "respects MAX_PAGES limit" do
    pdf_path = Rails.root.join("test/fixtures/files/sample.pdf")
    skip "Sample PDF not found" unless File.exist?(pdf_path)

    extractor = PdfSectionExtractor.new(pdf_path)
    analysis = extractor.analyze

    assert analysis[:primary_content][:page_count] <= PdfSectionExtractor::MAX_PAGES
  end

  # Optional integration test - requires sample PDF with bookmarks in tmp/samples/
  # This test is skipped in CI and standard test runs where the file doesn't exist
  test "uses outline detection when PDF has Meeting Agenda bookmark" do
    pdf_path = Rails.root.join("tmp/samples/Agenda_2014_12_15_Meeting(96).pdf")
    skip "Outline PDF not found in tmp/samples (optional integration test)" unless File.exist?(pdf_path)

    extractor = PdfSectionExtractor.new(pdf_path)
    analysis = extractor.analyze

    # This specific PDF has bookmarks, so outline detection should be used
    assert_equal :outline, analysis[:detection_method], "Expected outline detection for PDF with bookmarks"
    assert analysis[:primary_content][:start_page] >= 1
    assert analysis[:primary_content][:end_page] <= extractor.page_count
    assert analysis[:primary_content][:end_page] <= PdfSectionExtractor::MAX_PAGES
  end
end
