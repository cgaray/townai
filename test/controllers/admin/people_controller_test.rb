# frozen_string_literal: true

require "test_helper"

class Admin::PeopleControllerTest < ActionDispatch::IntegrationTest
  setup do
    @town = towns(:arlington)
    @source_person = people(:jon_smith)
    @target_person = people(:john_smith)
    @document = documents(:complete_agenda)

    # Clean up any existing document_attendees to avoid uniqueness conflicts
    DocumentAttendee.where(document: @document).delete_all
  end

  test "merge redirects to target person on success" do
    post admin_people_merge_url(source_id: @source_person.id, target_id: @target_person.id)

    assert_redirected_to town_person_url(@town, @target_person)
    follow_redirect!
    assert_match(/Successfully merged/, flash[:notice])
  end

  test "merge moves attendees from source to target" do
    source_attendee = attendees(:jon_smith_finance)
    original_target_attendees_count = @target_person.attendees.count

    post admin_people_merge_url(source_id: @source_person.id, target_id: @target_person.id)

    @target_person.reload
    source_attendee.reload

    assert_equal @target_person, source_attendee.person
    assert_equal original_target_attendees_count + 1, @target_person.attendees.count
  end

  test "merge deletes source person" do
    source_id = @source_person.id

    post admin_people_merge_url(source_id: @source_person.id, target_id: @target_person.id)

    assert_nil Person.find_by(id: source_id)
  end

  test "merge redirects with error when source not found" do
    post admin_people_merge_url(source_id: 999999, target_id: @target_person.id)

    assert_redirected_to towns_url
    assert_match(/not found/, flash[:alert])
  end

  test "merge redirects with error when target not found" do
    post admin_people_merge_url(source_id: @source_person.id, target_id: 999999)

    assert_redirected_to towns_url
    assert_match(/not found/, flash[:alert])
  end

  test "unmerge creates new person for attendee" do
    # First merge two attendees under one person
    second_attendee = attendees(:j_smith_finance)
    second_attendee.update!(person: @target_person)
    @target_person.update_appearances_count!

    original_person_count = Person.count

    post admin_people_unmerge_url(attendee_id: second_attendee.id)

    assert_equal original_person_count + 1, Person.count
    second_attendee.reload
    assert_not_equal @target_person, second_attendee.person
  end

  test "unmerge redirects to new person on success" do
    # First merge two attendees under one person
    second_attendee = attendees(:j_smith_finance)
    second_attendee.update!(person: @target_person)
    @target_person.update_appearances_count!

    post admin_people_unmerge_url(attendee_id: second_attendee.id)

    second_attendee.reload
    assert_redirected_to town_person_url(@town, second_attendee.person)
    follow_redirect!
    assert_match(/Successfully unmerged/, flash[:notice])
  end

  test "unmerge fails when person has only one attendee" do
    single_attendee = attendees(:john_smith_finance)

    post admin_people_unmerge_url(attendee_id: single_attendee.id)

    assert_redirected_to town_person_url(@town, @target_person)
    assert_match(/Unmerge failed/, flash[:alert])
  end

  test "unmerge redirects with error when attendee not found" do
    post admin_people_unmerge_url(attendee_id: 999999)

    assert_redirected_to towns_url
    assert_match(/not found/, flash[:alert])
  end
end
