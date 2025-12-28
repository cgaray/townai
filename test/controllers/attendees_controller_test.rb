require "test_helper"

class AttendeesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @attendee = attendees(:john_smith_finance)
  end

  test "should get index" do
    get attendees_url
    assert_response :success
    assert_select "h1", /Attendees/
  end

  test "index shows attendee cards" do
    get attendees_url
    assert_response :success
    assert_select ".card", minimum: 1
  end

  test "index shows governing body counts" do
    get attendees_url
    assert_response :success
    # Should show badges with governing body names
    assert_select ".badge", /Finance Committee/
  end

  test "should get show" do
    get attendee_url(@attendee)
    assert_response :success
    assert_select "h1", @attendee.name
  end

  test "show displays governing body" do
    get attendee_url(@attendee)
    assert_response :success
    assert_match @attendee.primary_governing_body, response.body
  end

  test "show redirects merged attendee to canonical" do
    merged = attendees(:merged_attendee)
    canonical = attendees(:john_smith_finance)

    get attendee_url(merged)
    assert_redirected_to attendee_url(canonical)
    follow_redirect!
    assert_match "Redirected to merged attendee profile", flash[:notice]
  end

  test "show displays potential duplicates section when duplicates exist" do
    # john_smith_finance has duplicates: john_smith_planning (same name diff body)
    # and jon_smith_finance (similar name)
    get attendee_url(@attendee)
    assert_response :success
    assert_match /Potential Duplicates/, response.body
  end

  test "show displays co-attendees when present" do
    # Create a document with multiple attendees
    doc = documents(:complete_agenda)
    jane = attendees(:jane_doe_finance)

    # Link both to the same document
    DocumentAttendee.find_or_create_by!(document: doc, attendee: @attendee) do |da|
      da.role = "chair"
    end
    DocumentAttendee.find_or_create_by!(document: doc, attendee: jane) do |da|
      da.role = "member"
    end

    get attendee_url(@attendee)
    assert_response :success
    assert_match /Frequently Seen With/, response.body
  end
end
