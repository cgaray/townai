require "test_helper"

class PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @person = people(:john_smith)
  end

  test "should get index" do
    get people_url
    assert_response :success
    assert_select "h1", /People/
  end

  test "index shows person cards" do
    get people_url
    assert_response :success
    assert_select ".card", minimum: 1
  end

  test "should get show" do
    get person_url(@person)
    assert_response :success
    assert_select "h1", @person.name
  end

  test "show displays governing body" do
    get person_url(@person)
    assert_response :success
    # Should show the primary governing body
    assert_match(/Finance Committee/, response.body)
  end

  test "show displays potential duplicates section when duplicates exist" do
    # john_smith has duplicates: john_smith_planning_person (same name)
    # and jon_smith (similar name)
    get person_url(@person)
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

    get person_url(@person)
    assert_response :success
    assert_match(/Frequently Seen With/, response.body)
  end

  test "show displays extracted identities when person has multiple attendees" do
    # Merge two attendees under one person
    person = people(:john_smith)
    second_attendee = attendees(:j_smith_finance)
    second_attendee.update!(person: person)

    get person_url(person)
    assert_response :success
    assert_match(/Extracted Identities/, response.body)
  end
end
