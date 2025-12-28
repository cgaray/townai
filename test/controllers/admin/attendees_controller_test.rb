require "test_helper"

class Admin::AttendeesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @source = attendees(:jon_smith_finance)
    @target = attendees(:john_smith_finance)
    @document = documents(:complete_agenda)

    # Clean up any existing document_attendees to avoid uniqueness conflicts
    DocumentAttendee.where(document: @document).delete_all

    # Create a document link for source attendee
    DocumentAttendee.create!(
      document: @document,
      attendee: @source,
      role: "member",
      status: "present"
    )
  end

  test "merge redirects to target attendee on success" do
    post admin_attendees_merge_url(source_id: @source.id, target_id: @target.id)

    assert_redirected_to attendee_url(@target)
    follow_redirect!
    assert_match /Successfully merged/, flash[:notice]
  end

  test "merge marks source as merged" do
    post admin_attendees_merge_url(source_id: @source.id, target_id: @target.id)

    @source.reload
    assert @source.merged?
    assert_equal @target, @source.merged_into
  end

  test "merge redirects with error when source not found" do
    post admin_attendees_merge_url(source_id: 999999, target_id: @target.id)

    assert_redirected_to attendees_url
    assert_match /not found/, flash[:alert]
  end

  test "merge redirects with error when target not found" do
    post admin_attendees_merge_url(source_id: @source.id, target_id: 999999)

    assert_redirected_to attendees_url
    assert_match /not found/, flash[:alert]
  end

  test "merge redirects to source with error on merge failure" do
    # Try to merge already merged attendee
    merged = attendees(:merged_attendee)

    post admin_attendees_merge_url(source_id: merged.id, target_id: @target.id)

    assert_redirected_to attendee_url(merged)
    assert_match /Merge failed/, flash[:alert]
  end
end
