# frozen_string_literal: true

require "test_helper"

module Admin
  class DocumentsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @admin = users(:admin)
      @user = users(:user)
      @document = documents(:complete_agenda)
      @failed_document = documents(:failed_document)
      sign_in @admin
    end

    # Authorization tests
    test "redirects non-admin users to root" do
      sign_out :user
      sign_in @user
      get admin_documents_url
      assert_redirected_to root_url
    end

    test "redirects unauthenticated users to login" do
      sign_out :user
      get admin_documents_url
      assert_redirected_to new_user_session_url
    end

    # Index tests
    test "should get index" do
      get admin_documents_url
      assert_response :success
    end

    test "index displays documents" do
      get admin_documents_url
      assert_response :success
      assert_select "table"
    end

    test "index filters by stage" do
      %w[pending extracting pending_review complete failed rejected].each do |stage|
        get admin_documents_url, params: { stage: stage }
        assert_response :success
      end
    end

    test "index filters by governing body" do
      get admin_documents_url, params: { governing_body_id: @document.governing_body_id }
      assert_response :success
    end

    test "index filters by confidence for pending_review stage" do
      get admin_documents_url, params: { stage: "pending_review", confidence: "low" }
      assert_response :success
    end

    # Destroy tests
    test "should destroy document" do
      assert_difference("Document.count", -1) do
        delete admin_document_url(@document)
      end

      assert_redirected_to admin_documents_url
      assert_match(/deleted successfully/, flash[:notice])
    end

    test "destroy enqueues audit log job" do
      assert_enqueued_with(job: AuditLogJob) do
        delete admin_document_url(@document)
      end
    end

    # Reextract tests
    test "should reextract document" do
      post reextract_admin_document_url(@document)

      assert_redirected_to admin_documents_url
      assert_match(/queued for re-extraction/, flash[:notice])

      @document.reload
      assert_equal "pending", @document.status
      assert_nil @document.extracted_metadata
    end

    test "reextract clears existing topics" do
      # Ensure document has topics
      assert @document.topics.count > 0, "Document should have topics for this test"

      assert_difference("Topic.count", -@document.topics.count) do
        post reextract_admin_document_url(@document)
      end
    end

    test "reextract enqueues extract metadata job" do
      assert_enqueued_with(job: ExtractMetadataJob) do
        post reextract_admin_document_url(@document)
      end
    end

    test "reextract enqueues audit log job" do
      assert_enqueued_with(job: AuditLogJob) do
        post reextract_admin_document_url(@document)
      end
    end

    # Bulk retry tests
    test "bulk retry queues all failed documents in governing body" do
      governing_body = @failed_document.governing_body

      post bulk_retry_admin_documents_url, params: { governing_body_id: governing_body.id }

      assert_redirected_to admin_documents_url(stage: "pending")
      assert_match(/queued for re-extraction/, flash[:notice])

      @failed_document.reload
      assert_equal "pending", @failed_document.status
    end

    test "bulk retry with no failed documents shows alert" do
      governing_body = documents(:complete_agenda).governing_body
      # Ensure no failed documents in this governing body
      governing_body.documents.failed.update_all(status: :complete)

      post bulk_retry_admin_documents_url, params: { governing_body_id: governing_body.id }

      assert_redirected_to admin_documents_url(stage: "failed", governing_body_id: governing_body.id)
      assert_match(/No failed documents/, flash[:alert])
    end

    test "bulk retry enqueues audit log job" do
      governing_body = @failed_document.governing_body

      assert_enqueued_with(job: AuditLogJob) do
        post bulk_retry_admin_documents_url, params: { governing_body_id: governing_body.id }
      end
    end

    # Show tests
    test "should show document" do
      get admin_document_url(@document)
      assert_response :success
    end

    test "show displays document metadata" do
      pending_doc = documents(:pending_review_document)
      get admin_document_url(pending_doc)
      assert_response :success
    end

    test "show includes edit form for pending_review documents" do
      pending_doc = documents(:pending_review_document)
      get admin_document_url(pending_doc)
      assert_response :success
      assert_select "form"
    end

    # Create tests (upload is now via modal, no separate new page)
    test "create without files shows error" do
      post admin_documents_url, params: { town_id: towns(:arlington).id }
      assert_redirected_to admin_documents_path
      assert_match(/select at least one/, flash[:alert])
    end

    # Update tests (edit is now inline on show page)
    test "update changes governing body" do
      pending_doc = documents(:pending_review_document)
      new_body = governing_bodies(:redevelopment_board)

      patch admin_document_url(pending_doc), params: {
        document: { governing_body_id: new_body.id }
      }

      assert_redirected_to admin_documents_url(stage: "pending_review")
      pending_doc.reload
      assert_equal new_body.id, pending_doc.governing_body_id
    end

    test "update enqueues audit log job" do
      pending_doc = documents(:pending_review_document)

      assert_enqueued_with(job: AuditLogJob) do
        patch admin_document_url(pending_doc), params: {
          document: { governing_body_id: governing_bodies(:redevelopment_board).id }
        }
      end
    end

    # Approve tests
    test "approve transitions document to complete" do
      pending_doc = documents(:pending_review_document)

      post approve_admin_document_url(pending_doc)

      pending_doc.reload
      assert pending_doc.complete?
      assert_equal @admin, pending_doc.reviewed_by
      assert_not_nil pending_doc.reviewed_at
    end

    test "approve redirects back to documents with pending_review stage" do
      pending_doc = documents(:pending_review_document)
      post approve_admin_document_url(pending_doc)
      assert_redirected_to admin_documents_url(stage: "pending_review")
    end

    test "approve enqueues audit log job" do
      pending_doc = documents(:pending_review_document)

      assert_enqueued_with(job: AuditLogJob) do
        post approve_admin_document_url(pending_doc)
      end
    end

    # Reject tests
    test "reject transitions document to rejected" do
      pending_doc = documents(:pending_review_document)

      post reject_admin_document_url(pending_doc), params: { reason: "Poor quality" }

      pending_doc.reload
      assert pending_doc.rejected?
      assert_equal @admin, pending_doc.reviewed_by
      assert_equal "Poor quality", pending_doc.rejection_reason
    end

    test "reject redirects back to documents with pending_review stage" do
      pending_doc = documents(:pending_review_document)
      post reject_admin_document_url(pending_doc)
      assert_redirected_to admin_documents_url(stage: "pending_review")
    end

    test "reject enqueues audit log job" do
      pending_doc = documents(:pending_review_document)

      assert_enqueued_with(job: AuditLogJob) do
        post reject_admin_document_url(pending_doc)
      end
    end

    # Bulk approve tests
    test "bulk approve approves filtered documents" do
      # Get count of pending_review documents
      pending_count = Document.needs_review.count
      assert pending_count > 0, "Should have pending_review documents"

      post bulk_approve_admin_documents_url

      # All should be approved
      assert_equal 0, Document.needs_review.count
    end

    test "bulk approve filters by governing body" do
      governing_body = documents(:pending_review_document).governing_body
      initial_count = Document.needs_review.where(governing_body: governing_body).count

      post bulk_approve_admin_documents_url, params: { governing_body_id: governing_body.id }

      assert_equal 0, Document.needs_review.where(governing_body: governing_body).count
      assert_redirected_to admin_documents_url(stage: "pending_review")
    end

    test "bulk approve filters by confidence" do
      initial_count = Document.needs_review.where(extraction_confidence: "high").count

      post bulk_approve_admin_documents_url, params: { confidence: "high" }

      assert_equal 0, Document.needs_review.where(extraction_confidence: "high").count
    end

    test "bulk approve enqueues audit log job" do
      assert_enqueued_with(job: AuditLogJob) do
        post bulk_approve_admin_documents_url
      end
    end
  end
end
