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

    test "index filters by status" do
      get admin_documents_url, params: { status: "complete" }
      assert_response :success
    end

    test "index filters by governing body" do
      get admin_documents_url, params: { governing_body_id: @document.governing_body_id }
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

      assert_redirected_to admin_documents_url(governing_body_id: governing_body.id)
      assert_match(/queued for re-extraction/, flash[:notice])

      @failed_document.reload
      assert_equal "pending", @failed_document.status
    end

    test "bulk retry with no failed documents shows alert" do
      governing_body = documents(:complete_agenda).governing_body
      # Ensure no failed documents in this governing body
      governing_body.documents.failed.update_all(status: :complete)

      post bulk_retry_admin_documents_url, params: { governing_body_id: governing_body.id }

      assert_redirected_to admin_documents_url(governing_body_id: governing_body.id)
      assert_match(/No failed documents/, flash[:alert])
    end

    test "bulk retry enqueues audit log job" do
      governing_body = @failed_document.governing_body

      assert_enqueued_with(job: AuditLogJob) do
        post bulk_retry_admin_documents_url, params: { governing_body_id: governing_body.id }
      end
    end
  end
end
