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

    sign_in users(:admin)
  end

  # === Index ===

  test "index renders successfully" do
    get admin_people_url
    assert_response :success
  end

  test "index filters by town" do
    get admin_people_url(town_id: @town.id)
    assert_response :success
  end

  # === Duplicates ===

  test "duplicates renders successfully" do
    get duplicates_admin_people_url
    assert_response :success
  end

  test "duplicates shows last computed timestamp" do
    # Run the job to populate suggestions
    ComputeDuplicatesJob.perform_now

    get duplicates_admin_people_url
    assert_response :success
    assert_match(/Last computed/, response.body)
  end

  test "duplicates shows never computed message when empty" do
    DuplicateSuggestion.delete_all

    get duplicates_admin_people_url
    assert_response :success
    assert_match(/Never computed/, response.body)
  end

  test "duplicates filters by town" do
    ComputeDuplicatesJob.perform_now

    get duplicates_admin_people_url(town_id: @town.id)
    assert_response :success
  end

  # === Recompute Duplicates ===

  test "recompute_duplicates enqueues job" do
    assert_enqueued_with(job: ComputeDuplicatesJob) do
      post recompute_duplicates_admin_people_url
    end

    assert_redirected_to duplicates_admin_people_url
    assert_match(/job queued/, flash[:notice])
  end

  test "recompute_duplicates logs audit event" do
    assert_enqueued_with(job: AuditLogJob) do
      post recompute_duplicates_admin_people_url
    end
  end

  # === Merge ===

  test "merge redirects to target person on success" do
    post merge_admin_people_url(source_id: @source_person.id, target_id: @target_person.id)

    assert_redirected_to town_person_url(@town, @target_person)
    follow_redirect!
    assert_match(/Successfully merged/, flash[:notice])
  end

  test "merge moves attendees from source to target" do
    source_attendee = attendees(:jon_smith_finance)
    original_target_attendees_count = @target_person.attendees.count

    post merge_admin_people_url(source_id: @source_person.id, target_id: @target_person.id)

    @target_person.reload
    source_attendee.reload

    assert_equal @target_person, source_attendee.person
    assert_equal original_target_attendees_count + 1, @target_person.attendees.count
  end

  test "merge deletes source person" do
    source_id = @source_person.id

    post merge_admin_people_url(source_id: @source_person.id, target_id: @target_person.id)

    assert_nil Person.find_by(id: source_id)
  end

  test "merge deletes stale duplicate suggestions" do
    source_id = @source_person.id
    target_id = @target_person.id

    # Create a suggestion involving the source person
    lower_id, higher_id = [ source_id, target_id ].sort
    suggestion = DuplicateSuggestion.create!(
      person_id: lower_id,
      duplicate_person_id: higher_id,
      match_type: :similar,
      similarity_score: 1
    )

    assert_equal 1, DuplicateSuggestion.involving(source_id).count
    assert Person.exists?(source_id), "Source person should exist before merge"

    post merge_admin_people_url(source_id: source_id, target_id: target_id)

    # Follow redirect to see flash message
    follow_redirect!
    assert_match(/Successfully merged/, flash[:notice] || "",
                 "Merge should succeed. Alert: #{flash[:alert]}")

    assert_not Person.exists?(source_id), "Source person should be deleted after merge"

    # Suggestion should be deleted after merge
    assert_not DuplicateSuggestion.exists?(suggestion.id),
               "Suggestion #{suggestion.id} should be deleted after merge"
  end

  test "merge redirects with error when source not found" do
    post merge_admin_people_url(source_id: 999999, target_id: @target_person.id)

    assert_redirected_to towns_url
    assert_match(/not found/, flash[:alert])
  end

  test "merge redirects with error when target not found" do
    post merge_admin_people_url(source_id: @source_person.id, target_id: 999999)

    assert_redirected_to towns_url
    assert_match(/not found/, flash[:alert])
  end

  # === Unmerge ===

  test "unmerge creates new person for attendee" do
    # First merge two attendees under one person
    second_attendee = attendees(:j_smith_finance)
    second_attendee.update!(person: @target_person)
    @target_person.update_appearances_count!

    original_person_count = Person.count

    post unmerge_admin_people_url(attendee_id: second_attendee.id)

    assert_equal original_person_count + 1, Person.count
    second_attendee.reload
    assert_not_equal @target_person, second_attendee.person
  end

  test "unmerge redirects to new person on success" do
    # First merge two attendees under one person
    second_attendee = attendees(:j_smith_finance)
    second_attendee.update!(person: @target_person)
    @target_person.update_appearances_count!

    post unmerge_admin_people_url(attendee_id: second_attendee.id)

    second_attendee.reload
    assert_redirected_to town_person_url(@town, second_attendee.person)
    follow_redirect!
    assert_match(/Successfully unmerged/, flash[:notice])
  end

  test "unmerge fails when person has only one attendee" do
    single_attendee = attendees(:john_smith_finance)

    post unmerge_admin_people_url(attendee_id: single_attendee.id)

    assert_redirected_to town_person_url(@town, @target_person)
    assert_match(/Unmerge failed/, flash[:alert])
  end

  test "unmerge redirects with error when attendee not found" do
    post unmerge_admin_people_url(attendee_id: 999999)

    assert_redirected_to towns_url
    assert_match(/not found/, flash[:alert])
  end
end
