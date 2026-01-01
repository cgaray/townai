require "test_helper"

class ReindexSearchJobTest < ActiveJob::TestCase
  test "performs job with document entity_type" do
    document = documents(:complete_agenda)
    
    # Just test that it doesn't raise an error
    assert_nothing_raised do
      ReindexSearchJob.perform_now("document", document.id)
    end
  end

  test "performs job with person entity_type" do
    person = people(:john_smith)
    
    assert_nothing_raised do
      ReindexSearchJob.perform_now("person", person.id)
    end
  end

  test "performs job with governing_body entity_type" do
    governing_body = governing_bodies(:select_board)
    
    assert_nothing_raised do
      ReindexSearchJob.perform_now("governing_body", governing_body.id)
    end
  end

  test "handles non-existent document gracefully" do
    non_existent_id = 999_999
    
    # Should not raise an error when document doesn't exist
    assert_nothing_raised do
      ReindexSearchJob.perform_now("document", non_existent_id)
    end
  end

  test "handles non-existent person gracefully" do
    non_existent_id = 999_999
    
    assert_nothing_raised do
      ReindexSearchJob.perform_now("person", non_existent_id)
    end
  end

  test "handles non-existent governing_body gracefully" do
    non_existent_id = 999_999
    
    assert_nothing_raised do
      ReindexSearchJob.perform_now("governing_body", non_existent_id)
    end
  end

  test "handles unknown entity_type gracefully" do
    # Unknown entity_type should not raise an error
    assert_nothing_raised do
      ReindexSearchJob.perform_now("unknown_type", 123)
    end
  end

  test "job can be enqueued" do
    assert_enqueued_with(job: ReindexSearchJob, args: [ "document", 1 ]) do
      ReindexSearchJob.perform_later("document", 1)
    end
  end

  test "job uses default queue" do
    job = ReindexSearchJob.new("document", 1)
    assert_equal "default", job.queue_name
  end
end
