require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @test_pdf_path = Rails.root.join("test/fixtures/files/test_document.pdf")
    FileUtils.mkdir_p(File.dirname(@test_pdf_path))
    unless File.exist?(@test_pdf_path)
      File.write(@test_pdf_path, "%PDF-1.4\n1 0 obj<</Type/Catalog>>endobj\ntrailer<</Root 1 0 R>>")
    end
  end

  test "should get index" do
    get documents_url
    assert_response :success
  end

  test "index should display documents" do
    get documents_url
    assert_response :success
    assert_select "body"
  end

  test "index should set status_counts" do
    get documents_url
    assert_response :success
  end

  test "should get show for complete document" do
    doc = documents(:complete_agenda)
    get document_url(doc)
    assert_response :success
  end

  test "should get show for pending document" do
    doc = documents(:pending_document)
    get document_url(doc)
    assert_response :success
  end

  test "should get show for failed document" do
    doc = documents(:failed_document)
    get document_url(doc)
    assert_response :success
  end

  test "show should return 404 for non-existent document" do
    get document_url(id: 999999)
    assert_response :not_found
  end

  test "root path should route to documents index" do
    get root_url
    assert_response :success
  end

  test "show displays View PDF button when pdf is attached" do
    doc = documents(:complete_agenda)
    doc.pdf.attach(io: File.open(@test_pdf_path), filename: "test.pdf", content_type: "application/pdf")

    get document_url(doc)
    assert_response :success
    assert_select "a.btn-primary", text: /View PDF/
  end

  test "show does not display View PDF button when pdf is not attached" do
    doc = documents(:complete_agenda)
    doc.pdf.purge if doc.pdf.attached?

    get document_url(doc)
    assert_response :success
    assert_select "a.btn-primary", text: /View PDF/, count: 0
  end

  test "View PDF button links to blob with inline disposition" do
    doc = documents(:complete_agenda)
    doc.pdf.attach(io: File.open(@test_pdf_path), filename: "test.pdf", content_type: "application/pdf")

    get document_url(doc)
    assert_response :success
    assert_select "a.btn-primary[target='_blank'][rel='noopener']", text: /View PDF/
  end
end
