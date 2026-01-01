# frozen_string_literal: true

require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
    @person = people(:john_smith)
    sign_in users(:user)
  end

  test "should get index" do
    get town_people_url(@town)
    assert_response :success
    assert_select "h1", /People/
  end

  test "index shows person cards" do
    get town_people_url(@town)
    assert_response :success
    assert_select ".card", minimum: 1
  end

  test "should get show" do
    get town_person_url(@town, @person)
    assert_response :success
    assert_select "h1", @person.name
  end

  test "show displays governing body" do
    get town_person_url(@town, @person)
    assert_response :success
    # Should show the primary governing body (Select Board from fixture)
    assert_match(/Select Board/, response.body)
  end

  test "show displays potential duplicates section when duplicates exist" do
    # john_smith has duplicates: john_smith_planning_person (same name)
    # and jon_smith (similar name)
    get town_person_url(@town, @person)
    assert_response :success
    assert_match(/Potential Duplicates/, response.body)
  end

  test "show displays co-people when present" do
    # Create a document with multiple attendees from different people
    doc = documents(:complete_agenda)
    john_attendee = attendees(:john_smith_finance)
    jane_attendee = attendees(:jane_doe_finance)

    # Link both to the same document
    DocumentAttendee.find_or_create_by!(document: doc, attendee: john_attendee) do |da|
      da.role = "chair"
    end
    DocumentAttendee.find_or_create_by!(document: doc, attendee: jane_attendee) do |da|
      da.role = "member"
    end

    # Update counter caches
    @person.update_appearances_count!
    people(:jane_doe).update_appearances_count!

    get town_person_url(@town, @person)
    assert_response :success
    assert_match(/Frequently Seen With/, response.body)
  end

  test "show displays extracted identities when person has multiple attendees" do
    # Merge two attendees under one person
    person = people(:john_smith)
    second_attendee = attendees(:j_smith_finance)
    second_attendee.update!(person: person)

    get town_person_url(@town, person)
    assert_response :success
    assert_match(/Extracted Identities/, response.body)
  end

  test "show displays topics discussed section" do
    get town_person_url(@town, @person)
    assert_response :success
    assert_match(/Topics Discussed/, response.body)
  end

  test "show displays topics from attended meetings" do
    # john_smith has john_smith_finance attendee linked to complete_agenda
    # which has topics including "Budget Amendment for FY2025"
    get town_person_url(@town, @person)
    assert_response :success
    assert_match(/Budget Amendment for FY2025/, response.body)
  end

  test "show displays action badges on topics" do
    get town_person_url(@town, @person)
    assert_response :success
    # Topics with actions should show action badges
    # budget_amendment has action_taken: approved
    assert_select ".badge", text: /Approved/i
  end

  test "show displays person role for each topic" do
    # john_at_agenda has role: chair
    get town_person_url(@town, @person)
    assert_response :success
    # Should show role badge - the "as" prefix indicates it's in the activity topic context
    assert_match(/as.*Chair/im, response.body)
  end

  test "show displays governing body for topics" do
    get town_person_url(@town, @person)
    assert_response :success
    assert_match(/Select Board/, response.body)
  end

  test "show displays topics count badge" do
    get town_person_url(@town, @person)
    assert_response :success
    # Should show total topics count
    assert_select ".badge", text: /topics/i
  end

  test "show displays explanatory text about committee decisions" do
    get town_person_url(@town, @person)
    assert_response :success
    # Should clarify that actions reflect committee decisions, not individual votes
    assert_match(/committee decisions/, response.body)
  end

  test "show topics link to document with anchor" do
    get town_person_url(@town, @person)
    assert_response :success
    # Topics should link to the document page with an anchor to the specific topic
    assert_select "a[href*='#topic-']"
  end

  test "show paginates topics" do
    get town_person_url(@town, @person, topics_page: 1)
    assert_response :success
  end

  test "show handles person with no topics" do
    # jon_smith has no document_attendees linking to any documents
    person = people(:jon_smith)
    get town_person_url(@town, person)
    assert_response :success
    # Should show empty state message
    assert_match(/No topics yet/, response.body)
  end
end
