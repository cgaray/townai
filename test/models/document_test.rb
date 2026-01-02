require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "should have valid statuses" do
    assert_equal %w[pending extracting_text extracting_metadata complete failed pending_review rejected], Document.statuses.keys
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
    assert_equal "Select Board", doc.metadata_field("governing_body")
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
    assert_equal 3, topics.length
    assert_equal "Budget Amendment for FY2025", topics.first["title"]
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

  test "pending_review? returns true for pending_review status" do
    doc = documents(:pending_review_document)
    assert doc.pending_review?
  end

  test "rejected? returns true for rejected status" do
    doc = documents(:rejected_document)
    assert doc.rejected?
  end

  test "needs_review scope returns pending_review documents" do
    pending_review_docs = Document.needs_review
    assert pending_review_docs.all?(&:pending_review?)
    assert_includes pending_review_docs, documents(:pending_review_document)
    assert_includes pending_review_docs, documents(:pending_review_low_confidence)
  end

  test "approved scope returns complete documents" do
    approved_docs = Document.approved
    assert approved_docs.all?(&:complete?)
  end

  test "calculate_confidence returns high for complete metadata" do
    metadata = {
      "document_type" => "agenda",
      "governing_body" => "Select Board",
      "meeting_date" => "2025-01-15",
      "attendees" => [ { "name" => "John" } ],
      "topics" => [ { "title" => "Topic 1" } ]
    }
    assert_equal "high", Document.calculate_confidence(metadata)
  end

  test "calculate_confidence returns medium for partial metadata" do
    metadata = {
      "document_type" => "agenda",
      "governing_body" => "Select Board",
      "meeting_date" => "2025-01-15",
      "attendees" => [],
      "topics" => []
    }
    assert_equal "medium", Document.calculate_confidence(metadata)
  end

  test "calculate_confidence returns low for minimal metadata" do
    metadata = {
      "document_type" => "agenda",
      "attendees" => [],
      "topics" => []
    }
    assert_equal "low", Document.calculate_confidence(metadata)
  end

  test "calculate_confidence returns low for invalid input" do
    assert_equal "low", Document.calculate_confidence(nil)
    assert_equal "low", Document.calculate_confidence("string")
  end

  test "approve! transitions to complete and records reviewer" do
    doc = documents(:pending_review_document)
    user = users(:admin)

    doc.approve!(user)

    assert doc.complete?
    assert_equal user, doc.reviewed_by
    assert_not_nil doc.reviewed_at
    assert_nil doc.rejection_reason
  end

  test "reject! transitions to rejected and records reason" do
    doc = documents(:pending_review_document)
    user = users(:admin)

    doc.reject!(user, reason: "Poor quality scan")

    assert doc.rejected?
    assert_equal user, doc.reviewed_by
    assert_not_nil doc.reviewed_at
    assert_equal "Poor quality scan", doc.rejection_reason
  end

  test "extraction_confidence enum works correctly" do
    doc = documents(:pending_review_document)
    assert doc.extraction_confidence_high?

    doc_low = documents(:pending_review_low_confidence)
    assert doc_low.extraction_confidence_low?
  end
end
