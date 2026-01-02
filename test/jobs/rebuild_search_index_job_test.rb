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
end
