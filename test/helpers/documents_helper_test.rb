require "test_helper"

class DocumentsHelperTest < ActionView::TestCase
  include IconsHelper

  test "status_badge returns badge for complete status" do
    result = status_badge("complete")
    assert_match(/badge-success/, result)
    assert_match(/Complete/, result)
  end

  test "status_badge returns badge for failed status" do
    result = status_badge("failed")
    assert_match(/badge-error/, result)
    assert_match(/Failed/, result)
  end

  test "status_badge returns badge for pending status" do
    result = status_badge("pending")
    assert_match(/badge-ghost/, result)
    assert_match(/Pending/, result)
  end

  test "status_badge returns warning badge for extracting statuses" do
    result = status_badge("extracting_text")
    assert_match(/badge-warning/, result)
    assert_match(/loading loading-spinner/, result)
  end

  test "status_icon_name returns check-circle for complete" do
    assert_equal "check-circle", status_icon_name("complete")
  end

  test "status_icon_name returns x-circle for failed" do
    assert_equal "x-circle", status_icon_name("failed")
  end

  test "status_icon_name returns clock-pending for pending" do
    assert_equal "clock-pending", status_icon_name("pending")
  end

  test "status_icon_name returns arrow-path for extracting statuses" do
    assert_equal "arrow-path", status_icon_name("extracting_text")
    assert_equal "arrow-path", status_icon_name("extracting_metadata")
  end

  test "document_type_border_class returns agenda border for agenda" do
    assert_equal "border-t-agenda", document_type_border_class("agenda")
    assert_equal "border-t-agenda", document_type_border_class("Agenda")
  end

  test "document_type_border_class returns minutes border for minutes" do
    assert_equal "border-t-minutes", document_type_border_class("minutes")
    assert_equal "border-t-minutes", document_type_border_class("Minutes")
  end

  test "document_type_border_class returns default border for unknown type" do
    assert_equal "border-t-default", document_type_border_class("unknown")
    assert_equal "border-t-default", document_type_border_class(nil)
  end

  # action_badge and action_border_class tests moved to TopicsHelperTest

  test "role_badge returns nil for blank role" do
    assert_nil role_badge(nil)
    assert_nil role_badge("")
  end

  test "role_badge returns primary badge for chair" do
    result = role_badge("chair")
    assert_match(/badge-primary/, result)
    assert_match(/Chair/, result)
  end

  test "role_badge returns secondary badge for clerk" do
    result = role_badge("clerk")
    assert_match(/badge-secondary/, result)
    assert_match(/Clerk/, result)
  end

  test "role_badge returns accent badge for staff" do
    result = role_badge("staff")
    assert_match(/badge-accent/, result)
    assert_match(/Staff/, result)
  end

  test "role_badge returns ghost badge for member" do
    result = role_badge("member")
    assert_match(/badge-ghost/, result)
    assert_match(/Member/, result)
  end

  test "avatar_initials returns ? for blank name" do
    assert_equal "?", avatar_initials(nil)
    assert_equal "?", avatar_initials("")
  end

  test "avatar_initials returns first and last initials for full name" do
    assert_equal "JS", avatar_initials("John Smith")
    assert_equal "JD", avatar_initials("Jane Doe")
    assert_equal "RJ", avatar_initials("Robert James Johnson")
  end

  test "avatar_initials returns first two characters for single name" do
    assert_equal "JO", avatar_initials("John")
    assert_equal "AL", avatar_initials("Alice")
  end

  test "avatar_initials returns uppercase" do
    assert_equal "JS", avatar_initials("john smith")
  end

  test "avatar_color_class returns base color for blank name" do
    assert_equal "bg-base-300 text-base-content", avatar_color_class(nil)
    assert_equal "bg-base-300 text-base-content", avatar_color_class("")
  end

  test "avatar_color_class returns consistent color for same name" do
    color1 = avatar_color_class("John Smith")
    color2 = avatar_color_class("John Smith")
    assert_equal color1, color2
  end

  test "avatar_color_class returns different colors for different names" do
    # This may occasionally fail if two names happen to hash to same value
    # but generally should produce different colors
    colors = %w[Alice Bob Carol Dave Eve Frank].map { |n| avatar_color_class(n) }
    # At least some should be different
    assert colors.uniq.length > 1
  end

  test "avatar_size_class returns correct classes for each size" do
    assert_equal "w-8 text-xs", avatar_size_class(:sm)
    assert_equal "w-10 text-sm", avatar_size_class(:md)
    assert_equal "w-12 text-base", avatar_size_class(:lg)
    assert_equal "w-16 text-lg", avatar_size_class(:xl)
  end

  test "avatar_size_class returns md size by default" do
    assert_equal "w-10 text-sm", avatar_size_class(nil)
    assert_equal "w-10 text-sm", avatar_size_class(:unknown)
  end

  test "avatar returns DaisyUI avatar placeholder markup" do
    result = avatar("John Smith")
    assert_match(/avatar avatar-placeholder/, result)
    assert_match(/rounded-full/, result)
    assert_match(/>JS</, result)
  end

  test "avatar uses correct size class" do
    result = avatar("John Smith", size: :lg)
    assert_match(/w-12/, result)
  end

  test "section_header returns h2 with icon and title" do
    result = section_header("Test Title", icon_name: "users")
    assert_match(/<h2/, result)
    assert_match(/Test Title/, result)
    assert_match(/<svg/, result)
  end

  test "section_header includes count badge when provided" do
    result = section_header("Test Title", icon_name: "users", count: 5)
    assert_match(/badge/, result)
    assert_match(/>5</, result)
  end

  test "section_header works without icon" do
    result = section_header("Test Title")
    assert_match(/<h2/, result)
    assert_match(/Test Title/, result)
  end

  test "document_type_badge returns primary badge for agenda" do
    result = document_type_badge("agenda")
    assert_match(/badge-primary/, result)
    assert_match(/Agenda/, result)
  end

  test "document_type_badge returns secondary badge for minutes" do
    result = document_type_badge("minutes")
    assert_match(/badge-secondary/, result)
    assert_match(/Minutes/, result)
  end

  test "document_type_badge returns ghost badge for unknown type" do
    result = document_type_badge("unknown")
    assert_match(/badge-ghost/, result)
  end

  test "document_type_badge handles nil" do
    result = document_type_badge(nil)
    assert_match(/Document/, result)
  end

  test "document_type_icon returns icon in circle for agenda" do
    result = document_type_icon("agenda")
    assert_match(/icon-circle/, result)
    assert_match(/<svg/, result)
  end

  test "document_type_icon returns icon in circle for minutes" do
    result = document_type_icon("minutes")
    assert_match(/icon-circle/, result)
  end

  test "document_type_icon accepts size parameter" do
    result = document_type_icon("agenda", size: :lg)
    assert_match(/icon-circle-lg/, result)
  end
end
