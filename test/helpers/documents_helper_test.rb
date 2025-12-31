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

  test "action_badge returns nil for blank action" do
    assert_nil action_badge(nil)
    assert_nil action_badge("")
  end

  test "action_badge returns success badge for approved" do
    result = action_badge("approved")
    assert_match(/badge-success/, result)
    assert_match(/Approved/, result)
  end

  test "action_badge returns error badge for denied" do
    result = action_badge("denied")
    assert_match(/badge-error/, result)
    assert_match(/Denied/, result)
  end

  test "action_badge returns warning badge for tabled" do
    result = action_badge("tabled")
    assert_match(/badge-warning/, result)
    assert_match(/Tabled/, result)
  end

  test "action_badge returns warning badge for continued" do
    result = action_badge("continued")
    assert_match(/badge-warning/, result)
    assert_match(/Continued/, result)
  end

  test "action_badge returns ghost badge for unknown action" do
    result = action_badge("none")
    assert_match(/badge-ghost/, result)
    assert_match(/None/, result)
  end

  test "action_border_class returns approved border for approved" do
    assert_equal "border-l-approved", action_border_class("approved")
  end

  test "action_border_class returns denied border for denied" do
    assert_equal "border-l-denied", action_border_class("denied")
  end

  test "action_border_class returns tabled border for tabled and continued" do
    assert_equal "border-l-tabled", action_border_class("tabled")
    assert_equal "border-l-tabled", action_border_class("continued")
  end

  test "action_border_class returns empty string for unknown action" do
    assert_equal "", action_border_class("none")
    assert_equal "", action_border_class("")
  end

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
end
