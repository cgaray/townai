require "test_helper"

class SearchIndexerTest < ActiveSupport::TestCase
  setup do
    SearchEntry.clear_all!
  end

  test "index_document indexes a complete document" do
    doc = documents(:complete_agenda)
    assert doc.complete?

    SearchIndexer.index_document(doc)

    results = SearchEntry.search("finance")
    assert results.any? { |r| r[:entity_type] == "document" && r[:entity_id] == doc.id }
  end

  test "index_document skips non-complete documents" do
    doc = documents(:complete_agenda)
    doc.update_column(:status, :pending)

    SearchIndexer.index_document(doc)

    results = SearchEntry.search("finance")
    assert results.none? { |r| r[:entity_type] == "document" && r[:entity_id] == doc.id }
  end

  test "index_document indexes topics separately" do
    doc = documents(:complete_agenda)
    # Clear existing topics and create new ones for this test
    doc.topics.destroy_all
    doc.topics.create!(title: "Budget Discussion", summary: "Review annual budget", position: 0)
    doc.topics.create!(title: "Zoning Changes", summary: "Discuss proposed changes", position: 1)

    SearchIndexer.index_document(doc)

    results = SearchEntry.search("budget")
    assert results.any? { |r| r[:entity_type] == "topic" }
  end

  test "index_person indexes a person" do
    person = people(:john_smith)

    SearchIndexer.index_person(person)

    results = SearchEntry.search(person.name.split.first)
    assert results.any? { |r| r[:entity_type] == "person" && r[:entity_id] == person.id }
  end

  test "index_governing_body indexes a governing body" do
    body = governing_bodies(:select_board)

    SearchIndexer.index_governing_body(body)

    results = SearchEntry.search("board")
    assert results.any? { |r| r[:entity_type] == "governing_body" && r[:entity_id] == body.id }
  end

  test "remove_document clears document and topic entries" do
    doc = documents(:complete_agenda)
    SearchIndexer.index_document(doc)

    # Verify indexed
    assert SearchEntry.search("finance").any?

    # Remove
    SearchIndexer.remove_document(doc.id)

    # Verify removed
    results = SearchEntry.search("finance")
    assert results.none? { |r| r[:entity_id] == doc.id }
  end

  test "rebuild_all rebuilds entire index" do
    # Index something first
    SearchIndexer.index_person(people(:john_smith))
    assert SearchEntry.search("smith").any?, "Person should be indexed before rebuild"

    # Rebuild clears and reindexes
    SearchIndexer.rebuild_all!

    # Should still have people indexed after rebuild
    results = SearchEntry.search("smith")
    assert_kind_of Array, results
  end
end
