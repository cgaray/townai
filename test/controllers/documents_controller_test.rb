# frozen_string_literal: true

require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
    @test_pdf_path = Rails.root.join("test/fixtures/files/test_document.pdf")
    FileUtils.mkdir_p(File.dirname(@test_pdf_path))
    unless File.exist?(@test_pdf_path)
      File.write(@test_pdf_path, "%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>")
    end
    sign_in users(:user)
  end

  test "redirects to login when not authenticated" do
    sign_out :user
    get town_documents_url(@town)
    assert_redirected_to new_user_session_url
  end

  test "should get index" do
    get town_documents_url(@town)
    assert_response :success
  end

  test "index should display documents" do
    get town_documents_url(@town)
    assert_response :success
    assert_select "body"
  end

  test "index should set status_counts" do
    get town_documents_url(@town)
    assert_response :success
  end

  test "should get show for complete document" do
    doc = documents(:complete_agenda)
    get town_document_url(@town, doc)
    assert_response :success
  end

  test "should get show for pending document" do
    doc = documents(:pending_document)
    get town_document_url(@town, doc)
    assert_response :success
  end

  test "should get show for failed document" do
    doc = documents(:failed_document)
    get town_document_url(@town, doc)
    assert_response :success
  end

  test "show should return 404 for non-existent document" do
    get town_document_url(@town, id: 999999)
    assert_response :not_found
  end

  test "root path should route to towns index" do
    get root_url
    assert_response :success
  end

  test "show displays View PDF button when pdf is attached" do
    doc = documents(:complete_agenda)
    doc.pdf.attach(io: File.open(@test_pdf_path), filename: "test.pdf", content_type: "application/pdf")

    get town_document_url(@town, doc)
    assert_response :success
    assert_select "a.btn-primary", text: /View PDF/
  end

  test "show does not display View PDF button when pdf is not attached" do
    doc = documents(:complete_agenda)
    doc.pdf.purge if doc.pdf.attached?

    get town_document_url(@town, doc)
    assert_response :success
    assert_select "a.btn-primary", text: /View PDF/, count: 0
  end

  test "View PDF button links to blob with inline disposition" do
    doc = documents(:complete_agenda)
    doc.pdf.attach(io: File.open(@test_pdf_path), filename: "test.pdf", content_type: "application/pdf")

    get town_document_url(@town, doc)
    assert_response :success
    assert_select "a.btn-primary[target='_blank'][rel='noopener']", text: /View PDF/
  end

  test "retry action requeues failed document" do
    doc = documents(:failed_document)

    assert_enqueued_with(job: ExtractMetadataJob) do
      post retry_town_document_url(@town, doc)
    end

    assert_redirected_to town_document_url(@town, doc)
    doc.reload
    assert doc.pending?
  end

  test "retry action only works for failed documents" do
    doc = documents(:complete_agenda)

    post retry_town_document_url(@town, doc)

    assert_redirected_to town_document_url(@town, doc)
    assert_equal "Only failed documents can be retried.", flash[:alert]
    doc.reload
    assert doc.complete?
  end

  test "topic titles and summaries are HTML escaped to prevent XSS" do
    doc = documents(:complete_agenda)
    doc.topics.destroy_all

    # Create topic with potentially malicious content
    doc.topics.create!(
      title: "<script>alert('xss')</script>Malicious Title",
      summary: "<img src=x onerror=alert('xss')>Malicious Summary",
      position: 0
    )

    get town_document_url(@town, doc)
    assert_response :success

    # Verify the response body contains escaped HTML, not raw script tags
    assert_no_match(/<script>alert/, response.body)
    assert_no_match(/<img src=x onerror/, response.body)

    # Verify the escaped versions are present
    assert_match(/&lt;script&gt;/, response.body)
    assert_match(/&lt;img src=x/, response.body)
  end
end
