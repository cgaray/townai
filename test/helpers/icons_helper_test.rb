require "test_helper"

class IconsHelperTest < ActionView::TestCase
  test "icon returns svg element" do
    result = icon("document")
    assert_match(/<svg/, result)
    assert_match(/<\/svg>/, result)
  end

  test "icon includes viewBox attribute" do
    result = icon("document")
    assert_match(/viewBox="0 0 24 24"/, result)
  end

  test "icon includes stroke attributes" do
    result = icon("document")
    assert_match(/stroke="currentColor"/, result)
    assert_match(/fill="none"/, result)
  end

  test "icon uses default size" do
    result = icon("document")
    assert_match(/class="w-5 h-5"/, result)
  end

  test "icon accepts custom size" do
    result = icon("document", size: "w-8 h-8")
    assert_match(/class="w-8 h-8"/, result)
  end

  test "icon accepts additional class" do
    result = icon("document", size: "w-5 h-5", class: "text-red-500")
    assert_match(/class="w-5 h-5 text-red-500"/, result)
  end

  test "icon accepts custom stroke width" do
    result = icon("document", stroke_width: 2)
    assert_match(/stroke-width="2"/, result)
  end

  test "icon returns document icon for document name" do
    result = icon("document")
    assert_match(/path/, result)
  end

  test "icon returns document icon for document-text name" do
    result = icon("document-text")
    assert_match(/path/, result)
  end

  test "icon returns agenda icon" do
    result = icon("agenda")
    assert_match(/path/, result)
  end

  test "icon returns minutes icon" do
    result = icon("minutes")
    assert_match(/path/, result)
  end

  test "icon returns calendar icon" do
    result = icon("calendar")
    assert_match(/path/, result)
  end

  test "icon returns clock icon" do
    result = icon("clock")
    assert_match(/path/, result)
  end

  test "icon returns users icon" do
    result = icon("users")
    assert_match(/path/, result)
  end

  test "icon returns check-circle icon" do
    result = icon("check-circle")
    assert_match(/path/, result)
  end

  test "icon returns x-circle icon" do
    result = icon("x-circle")
    assert_match(/path/, result)
  end

  test "icon returns arrow-path icon" do
    result = icon("arrow-path")
    assert_match(/path/, result)
  end

  test "icon returns building-library icon" do
    result = icon("building-library")
    assert_match(/path/, result)
  end

  test "icon returns chevron-left icon" do
    result = icon("chevron-left")
    assert_match(/path/, result)
  end

  test "icon returns chevron-right icon" do
    result = icon("chevron-right")
    assert_match(/path/, result)
  end

  test "icon returns folder-open icon" do
    result = icon("folder-open")
    assert_match(/path/, result)
  end

  test "icon returns bars-3 icon" do
    result = icon("bars-3")
    assert_match(/path/, result)
  end

  test "icon returns list-bullet icon" do
    result = icon("list-bullet")
    assert_match(/path/, result)
  end

  test "icon returns exclamation-circle icon" do
    result = icon("exclamation-circle")
    assert_match(/path/, result)
  end

  test "icon returns clock-pending icon" do
    result = icon("clock-pending")
    assert_match(/path/, result)
  end

  test "icon returns document-check icon" do
    result = icon("document-check")
    assert_match(/path/, result)
  end

  test "icon returns hand-raised icon" do
    result = icon("hand-raised")
    assert_match(/path/, result)
  end

  test "icon returns pause-circle icon" do
    result = icon("pause-circle")
    assert_match(/path/, result)
  end

  test "icon returns file icon" do
    result = icon("file")
    assert_match(/path/, result)
  end

  test "icon returns default icon for unknown name" do
    result = icon("unknown-icon-name")
    assert_match(/<svg/, result)
    assert_match(/path/, result)
  end

  test "icon_in_circle returns span with icon" do
    result = icon_in_circle("document")
    assert_match(/<span/, result)
    assert_match(/icon-circle/, result)
    assert_match(/<svg/, result)
  end

  test "icon_in_circle uses default medium size" do
    result = icon_in_circle("document")
    assert_match(/icon-circle-md/, result)
  end

  test "icon_in_circle accepts small size" do
    result = icon_in_circle("document", size: :sm)
    assert_match(/icon-circle-sm/, result)
  end

  test "icon_in_circle accepts large size" do
    result = icon_in_circle("document", size: :lg)
    assert_match(/icon-circle-lg/, result)
  end

  test "icon_in_circle accepts xl size" do
    result = icon_in_circle("document", size: :xl)
    assert_match(/icon-circle-xl/, result)
  end

  test "icon_in_circle accepts agenda type" do
    result = icon_in_circle("agenda", type: :agenda)
    assert_match(/icon-circle-agenda/, result)
  end

  test "icon_in_circle accepts minutes type" do
    result = icon_in_circle("minutes", type: :minutes)
    assert_match(/icon-circle-minutes/, result)
  end

  test "icon_in_circle accepts brand type" do
    result = icon_in_circle("building-library", type: :brand)
    assert_match(/icon-circle-brand/, result)
  end

  test "icon_in_circle uses default type for unknown type" do
    result = icon_in_circle("document", type: :unknown)
    assert_match(/icon-circle-default/, result)
  end

  test "icon_in_circle accepts additional classes" do
    result = icon_in_circle("document", options: { class: "custom-class" })
    assert_match(/custom-class/, result)
  end

  test "document_type_icon_with_circle returns agenda icon for agenda type" do
    result = document_type_icon_with_circle("agenda")
    assert_match(/icon-circle-agenda/, result)
  end

  test "document_type_icon_with_circle returns minutes icon for minutes type" do
    result = document_type_icon_with_circle("minutes")
    assert_match(/icon-circle-minutes/, result)
  end

  test "document_type_icon_with_circle returns default icon for unknown type" do
    result = document_type_icon_with_circle("unknown")
    assert_match(/icon-circle/, result)
  end

  test "document_type_icon_with_circle accepts size parameter" do
    result = document_type_icon_with_circle("agenda", size: :lg)
    assert_match(/icon-circle-lg/, result)
  end
end
