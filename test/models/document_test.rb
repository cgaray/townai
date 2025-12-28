require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "should have valid statuses" do
    assert_equal %w[pending extracting_text extracting_metadata complete failed], Document.statuses.keys
  end

  test "should default to pending status" do
    doc = Document.new(source_file_name: "test.pdf", source_file_hash: "unique_hash_123")
    assert doc.pending?
  end

  test "pending? returns true for pending status" do
    doc = documents(:pending_document)
    assert doc.pending?
  end

  test "extracting_text? returns true for extracting_text status" do
    doc = documents(:extracting_text_document)
    assert doc.extracting_text?
  end

  test "extracting_metadata? returns true for extracting_metadata status" do
    doc = documents(:extracting_metadata_document)
    assert doc.extracting_metadata?
  end

  test "complete? returns true for complete status" do
    doc = documents(:complete_agenda)
    assert doc.complete?
  end

  test "failed? returns true for failed status" do
    doc = documents(:failed_document)
    assert doc.failed?
  end

  test "metadata_field returns field value for complete document" do
    doc = documents(:complete_agenda)
    assert_equal "agenda", doc.metadata_field("document_type")
    assert_equal "Finance Committee", doc.metadata_field("governing_body")
    assert_equal "2025-01-10", doc.metadata_field("meeting_date")
  end

  test "metadata_field returns nil for non-existent field" do
    doc = documents(:complete_agenda)
    assert_nil doc.metadata_field("non_existent_field")
  end

  test "metadata_field returns nil when extracted_metadata is nil" do
    doc = documents(:pending_document)
    assert_nil doc.metadata_field("document_type")
  end

  test "metadata_field returns nil when extracted_metadata is empty" do
    doc = Document.new(source_file_name: "test.pdf", source_file_hash: "test", extracted_metadata: "")
    assert_nil doc.metadata_field("document_type")
  end

  test "metadata_field returns nil for invalid JSON" do
    doc = Document.new(source_file_name: "test.pdf", source_file_hash: "test", extracted_metadata: "invalid json")
    assert_nil doc.metadata_field("document_type")
  end

  test "metadata_field returns attendees array" do
    doc = documents(:complete_agenda)
    attendees = doc.metadata_field("attendees")
    assert_kind_of Array, attendees
    assert_equal 2, attendees.length
    assert_equal "John Smith", attendees.first["name"]
  end

  test "metadata_field returns topics array" do
    doc = documents(:complete_agenda)
    topics = doc.metadata_field("topics")
    assert_kind_of Array, topics
    assert_equal 2, topics.length
    assert_equal "Budget Review", topics.first["title"]
  end

  test "source_file_hash must be unique at database level" do
    existing = documents(:complete_agenda)
    duplicate = Document.new(
      source_file_name: "different_name.pdf",
      source_file_hash: existing.source_file_hash
    )
    # Uniqueness is enforced at the database level via index, not model validation
    assert_raises(ActiveRecord::RecordNotUnique) do
      duplicate.save!
    end
  end

  test "has_one_attached pdf" do
    doc = documents(:pending_document)
    assert_respond_to doc, :pdf
    assert_respond_to doc.pdf, :attach
    assert_respond_to doc.pdf, :attached?
  end
end
