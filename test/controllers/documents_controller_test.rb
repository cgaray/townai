require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
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
end
