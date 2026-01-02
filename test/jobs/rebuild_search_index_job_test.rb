# frozen_string_literal: true

require "test_helper"

class RebuildSearchIndexJobTest < ActiveJob::TestCase
  test "performs without error" do
    # Just verify the job runs without raising
    assert_nothing_raised do
      RebuildSearchIndexJob.perform_now
    end
  end

  test "can be enqueued" do
    assert_enqueued_with(job: RebuildSearchIndexJob) do
      RebuildSearchIndexJob.perform_later
    end
  end

  test "rebuilds search index with actual data" do
    # Create a document that should be indexed
    town = towns(:arlington)
    gb = governing_bodies(:select_board)
    doc = Document.create!(
      governing_body: gb,
      source_file_name: "search_test.pdf",
      status: :complete,
      extracted_metadata: { "title" => "Searchable Test Document" }.to_json
    )

    # Clear and rebuild the index
    SearchEntry.clear_all!
    assert_equal 0, SearchEntry.count

    RebuildSearchIndexJob.perform_now

    # Verify index was rebuilt with content
    assert SearchEntry.count > 0, "Search index should have entries after rebuild"
  ensure
    doc&.destroy
  end
end
