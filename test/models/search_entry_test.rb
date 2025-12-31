require "test_helper"

class SearchEntryTest < ActiveSupport::TestCase
  setup do
    SearchEntry.clear_all!
  end

  test "search returns empty array for blank query" do
    assert_equal [], SearchEntry.search("")
    assert_equal [], SearchEntry.search(nil)
  end

  test "search finds matching entries" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Town Meeting Agenda",
      subtitle: "Select Board",
      content: "Discussion of budget items",
      url: "/documents/1"
    )

    results = SearchEntry.search("budget")
    assert_equal 1, results.length
    assert_equal "document", results.first[:entity_type]
    assert_equal 1, results.first[:entity_id]
  end

  test "search with type filter" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Budget Meeting",
      subtitle: "Test",
      content: "Content",
      url: "/documents/1"
    )
    SearchEntry.insert_entry!(
      entity_type: "person",
      entity_id: 2,
      title: "Budget Officer",
      subtitle: "Test",
      content: "Content",
      url: "/people/2"
    )

    # Filter to documents only
    results = SearchEntry.search("budget", types: [ "document" ])
    assert results.all? { |r| r[:entity_type] == "document" }

    # Filter to people only
    results = SearchEntry.search("budget", types: [ "person" ])
    assert results.all? { |r| r[:entity_type] == "person" }
  end

  test "search with invalid type returns empty array" do
    results = SearchEntry.search("test", types: [ "invalid_type" ])
    assert_equal [], results
  end

  test "search returns highlighted snippets" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Test Document",
      subtitle: "Test",
      content: "The budget proposal was discussed at length during the meeting",
      url: "/documents/1"
    )

    results = SearchEntry.search("budget")
    assert results.first[:snippet].include?("<mark>")
  end

  test "counts_by_type returns counts grouped by entity type" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Budget Doc 1",
      subtitle: "",
      content: "",
      url: "/documents/1"
    )
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 2,
      title: "Budget Doc 2",
      subtitle: "",
      content: "",
      url: "/documents/2"
    )
    SearchEntry.insert_entry!(
      entity_type: "person",
      entity_id: 3,
      title: "Budget Officer",
      subtitle: "",
      content: "",
      url: "/people/3"
    )

    counts = SearchEntry.counts_by_type("budget")
    assert_equal 2, counts["document"]
    assert_equal 1, counts["person"]
  end

  test "counts_by_type returns empty hash for blank query" do
    assert_equal({}, SearchEntry.counts_by_type(""))
    assert_equal({}, SearchEntry.counts_by_type(nil))
  end

  test "clear_all removes all entries" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Test",
      subtitle: "",
      content: "",
      url: "/test"
    )

    assert SearchEntry.search("test").any?

    SearchEntry.clear_all!

    assert_equal [], SearchEntry.search("test")
  end

  test "clear_entity removes specific entity" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Test One",
      subtitle: "",
      content: "",
      url: "/documents/1"
    )
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 2,
      title: "Test Two",
      subtitle: "",
      content: "",
      url: "/documents/2"
    )

    SearchEntry.clear_entity!("document", 1)

    results = SearchEntry.search("test")
    assert results.none? { |r| r[:entity_id] == 1 }
    assert results.any? { |r| r[:entity_id] == 2 }
  end

  test "search handles special characters safely" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Normal Document",
      subtitle: "",
      content: "Normal content",
      url: "/documents/1"
    )

    # These shouldn't cause errors
    assert_nothing_raised { SearchEntry.search("test\"quote") }
    assert_nothing_raised { SearchEntry.search("test*wildcard") }
    assert_nothing_raised { SearchEntry.search("test(parens)") }
    assert_nothing_raised { SearchEntry.search("test:colon") }
  end

  test "search uses prefix matching for typeahead" do
    SearchEntry.insert_entry!(
      entity_type: "document",
      entity_id: 1,
      title: "Budget Meeting",
      subtitle: "",
      content: "",
      url: "/documents/1"
    )

    # Partial word should match due to prefix matching
    results = SearchEntry.search("budg")
    assert_equal 1, results.length
  end
end
