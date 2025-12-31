# frozen_string_literal: true

require "test_helper"

class GoverningBodyTest < ActiveSupport::TestCase
  test "requires name" do
    gb = GoverningBody.new(normalized_name: "test")
    assert_not gb.valid?
    assert_includes gb.errors[:name], "can't be blank"
  end

  test "auto-generates normalized_name from name" do
    gb = GoverningBody.new(name: "  Select Board  ")
    gb.valid?
    assert_equal "select board", gb.normalized_name
  end

  test "normalized_name must be unique" do
    GoverningBody.create!(name: "Unique Board")
    duplicate = GoverningBody.new(name: "unique board")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:normalized_name], "has already been taken"
  end

  test "find_or_create_by_name creates new record" do
    assert_difference "GoverningBody.count", 1 do
      gb = GoverningBody.find_or_create_by_name("Planning Board")
      assert_equal "Planning Board", gb.name
      assert_equal "planning board", gb.normalized_name
    end
  end

  test "find_or_create_by_name finds existing record" do
    existing = governing_bodies(:select_board)
    assert_no_difference "GoverningBody.count" do
      gb = GoverningBody.find_or_create_by_name("SELECT BOARD")
      assert_equal existing.id, gb.id
    end
  end

  test "find_or_create_by_name returns nil for blank name" do
    assert_nil GoverningBody.find_or_create_by_name("")
    assert_nil GoverningBody.find_or_create_by_name(nil)
  end

  test "normalize_name handles various inputs" do
    assert_equal "select board", GoverningBody.normalize_name("Select Board")
    assert_equal "select board", GoverningBody.normalize_name("  SELECT   BOARD  ")
    assert_equal "board of health", GoverningBody.normalize_name("Board of Health")
  end

  test "by_document_count scope orders by count descending" do
    high = GoverningBody.create!(name: "High Count", documents_count: 10)
    low = GoverningBody.create!(name: "Low Count", documents_count: 1)

    results = GoverningBody.by_document_count.where(id: [ high.id, low.id ])
    assert_equal [ high, low ], results.to_a
  end
end
