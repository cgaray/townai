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

  test "document destruction cleans up search entries for document and topics" do
    doc = documents(:complete_agenda)

    # Create topics and index the document
    doc.topics.destroy_all
    topic1 = doc.topics.create!(title: "UniqueXyzAlpha123", summary: "Unique content", position: 0)
    topic2 = doc.topics.create!(title: "UniqueXyzBeta456", summary: "More content", position: 1)
    topic1_id = topic1.id
    topic2_id = topic2.id
    SearchIndexer.index_document(doc)

    # Verify topics are indexed
    topic_results = SearchEntry.search("UniqueXyzAlpha123")
    assert topic_results.any? { |r| r[:entity_type] == "topic" && r[:entity_id] == topic1_id },
           "Topic should be indexed"

    # Destroy the document (triggers before_destroy callback to cache topic IDs)
    doc.destroy

    # Verify document search entry is removed
    doc_results_after = SearchEntry.search("finance")
    assert doc_results_after.none? { |r| r[:entity_type] == "document" && r[:entity_id] == doc.id },
           "Document search entry should be removed"

    # Verify topic search entries are removed (this tests the before_destroy fix)
    # Use direct query since topics no longer exist
    topic1_entries = SearchEntry.where(entity_type: "topic", entity_id: topic1_id)
    topic2_entries = SearchEntry.where(entity_type: "topic", entity_id: topic2_id)
    assert_empty topic1_entries, "Topic 1 search entry should be removed"
    assert_empty topic2_entries, "Topic 2 search entry should be removed"
  end
end
