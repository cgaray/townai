# frozen_string_literal: true

require "test_helper"

class TopicsHelperTest < ActionView::TestCase
  include IconsHelper

  test "action_badge returns nil for blank action" do
    assert_nil action_badge(nil)
    assert_nil action_badge("")
  end

  test "action_badge renders approved badge with success style" do
    result = action_badge("approved")
    assert_includes result, "badge-soft"
    assert_includes result, "badge-success"
    assert_includes result, "Approved"
  end

  test "action_badge renders denied badge with error style" do
    result = action_badge("denied")
    assert_includes result, "badge-soft"
    assert_includes result, "badge-error"
    assert_includes result, "Denied"
  end

  test "action_badge renders tabled badge with warning style" do
    result = action_badge("tabled")
    assert_includes result, "badge-soft"
    assert_includes result, "badge-warning"
    assert_includes result, "Tabled"
  end

  test "action_badge renders continued badge with warning style" do
    result = action_badge("continued")
    assert_includes result, "badge-soft"
    assert_includes result, "badge-warning"
    assert_includes result, "Continued"
  end

  test "action_badge handles unknown action with ghost style" do
    result = action_badge("unknown")
    assert_includes result, "badge-ghost"
    assert_includes result, "Unknown"
  end

  test "action_border_class returns correct class for approved" do
    assert_equal "border-l-approved", action_border_class("approved")
  end

  test "action_border_class returns correct class for denied" do
    assert_equal "border-l-denied", action_border_class("denied")
  end

  test "action_border_class returns correct class for tabled" do
    assert_equal "border-l-tabled", action_border_class("tabled")
  end

  test "action_border_class returns empty string for unknown action" do
    assert_equal "", action_border_class("unknown")
    assert_equal "", action_border_class(nil)
  end

  # Real usage passes symbols from enum, not strings
  test "action_badge handles symbol input from enum" do
    result = action_badge(:approved)
    assert_includes result, "badge-soft"
    assert_includes result, "badge-success"
    assert_includes result, "Approved"
  end

  test "action_border_class handles symbol input from enum" do
    assert_equal "border-l-approved", action_border_class(:approved)
    assert_equal "border-l-denied", action_border_class(:denied)
  end

  # topic_filter_pills tests
  test "topic_filter_pills renders all filter buttons" do
    town = towns(:arlington)
    filter_counts = { all: 10, with_actions: 5, approved: 2, denied: 1, tabled: 1, continued: 1 }

    result = topic_filter_pills(
      town: town,
      current_action: nil,
      governing_body_id: nil,
      filter_counts: filter_counts
    )

    assert_includes result, "All"
    assert_includes result, "With Actions"
    assert_includes result, "Approved"
    assert_includes result, "Denied"
    assert_includes result, "Tabled"
    assert_includes result, "Continued"
  end

  test "topic_filter_pills shows counts in badges" do
    town = towns(:arlington)
    filter_counts = { all: 42, with_actions: 5, approved: 2, denied: 1, tabled: 1, continued: 1 }

    result = topic_filter_pills(
      town: town,
      current_action: nil,
      governing_body_id: nil,
      filter_counts: filter_counts
    )

    assert_includes result, ">42<"
  end

  test "topic_filter_pills highlights active filter" do
    town = towns(:arlington)
    filter_counts = { all: 10, with_actions: 5, approved: 2, denied: 1, tabled: 1, continued: 1 }

    result = topic_filter_pills(
      town: town,
      current_action: "approved",
      governing_body_id: nil,
      filter_counts: filter_counts
    )

    # The approved button should have btn-success (active), not btn-ghost
    assert_includes result, "btn-success"
  end

  test "topic_filter_pills preserves governing_body_id in links" do
    town = towns(:arlington)
    governing_body = governing_bodies(:select_board)
    filter_counts = { all: 10, with_actions: 5, approved: 2, denied: 1, tabled: 1, continued: 1 }

    result = topic_filter_pills(
      town: town,
      current_action: nil,
      governing_body_id: governing_body.id,
      filter_counts: filter_counts
    )

    assert_includes result, "governing_body_id=#{governing_body.id}"
  end
end
