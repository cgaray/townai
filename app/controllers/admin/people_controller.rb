# frozen_string_literal: true

class Admin::PeopleController < Admin::BaseController
  def index
    @people = Person.includes(:town, attendees: :governing_body)
                    .order(:normalized_name)

    # Filter by town
    @people = @people.where(town_id: params[:town_id]) if params[:town_id].present?

    @pagy, @people = pagy(@people, limit: 50)

    # For filter dropdowns
    @towns = Town.joins(:people).distinct.order(:name)
  end

  def duplicates
    # Find all people who have potential duplicates
    @duplicate_groups = find_duplicate_groups

    # Filter by town if specified
    if params[:town_id].present?
      @duplicate_groups = @duplicate_groups.select do |group|
        group[:people].any? { |p| p.town_id.to_s == params[:town_id].to_s }
      end
    end

    @towns = Town.joins(:people).distinct.order(:name)
  end

  def merge
    source = Person.find(params[:source_id])
    target = Person.find(params[:target_id])

    merged_count = source.attendees.count
    previous_state = {
      source_attendee_count: source.attendees.count,
      target_attendee_count: target.attendees.count
    }

    merger = ::PersonMerger.new(source: source, target: target)

    if merger.merge!
      new_state = {
        source_attendee_count: 0,  # Source is deleted
        target_attendee_count: target.attendees.count,
        merged_count: merged_count
      }

      # Log admin action
      AuditLogJob.perform_later(
        user: current_user,
        action: "person_merge",
        resource_type: "Person",
        resource_id: target.id,
        previous_state: previous_state.to_json,
        new_state: new_state.to_json,
        ip_address: request.remote_ip
      )

      redirect_to person_redirect_path(target), notice: "Successfully merged #{source.name} into #{target.name}"
    else
      redirect_to person_redirect_path(target), alert: "Merge failed: #{merger.errors.join(', ')}"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to towns_path, alert: "Person not found"
  end

  def unmerge
    attendee = Attendee.find(params[:attendee_id])
    original_person = attendee.person

    previous_state = {
      attendee_id: attendee.id,
      person_id: original_person.id,
      attendee_count: original_person.attendees.count
    }

    unmerger = ::PersonUnmerger.new(attendee: attendee)

    if unmerger.unmerge!
      new_state = {
        original_person_id: original_person.id,
        new_person_id: unmerger.new_person.id,
        attendee_id: attendee.id,
        original_attendee_count: original_person.attendees.count,
        new_attendee_count: unmerger.new_person.attendees.count
      }

      # Log admin action
      AuditLogJob.perform_later(
        user: current_user,
        action: "person_unmerge",
        resource_type: "Person",
        resource_id: unmerger.new_person.id,
        previous_state: previous_state.to_json,
        new_state: new_state.to_json,
        ip_address: request.remote_ip
      )

      redirect_to person_redirect_path(unmerger.new_person),
                  notice: "Successfully unmerged #{attendee.name} into a new person"
    else
      redirect_to person_redirect_path(original_person),
                  alert: "Unmerge failed: #{unmerger.errors.join(', ')}"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to towns_path, alert: "Attendee not found"
  end

  private

  def person_redirect_path(person)
    if person.town
      town_person_path(person.town, person)
    else
      towns_path
    end
  end

  # Find groups of people who might be duplicates
  # Groups are formed by normalized_name or Levenshtein distance <= 2
  def find_duplicate_groups
    groups = []
    processed_ids = Set.new

    Person.includes(:town, attendees: :governing_body).find_each do |person|
      next if processed_ids.include?(person.id)

      duplicates = person.potential_duplicates
      same_name = duplicates[:same_name].to_a
      similar_name = duplicates[:similar_name].to_a

      all_duplicates = same_name + similar_name
      next if all_duplicates.empty?

      # Mark all as processed
      processed_ids.add(person.id)
      all_duplicates.each { |p| processed_ids.add(p.id) }

      groups << {
        normalized_name: person.normalized_name,
        people: [ person ] + all_duplicates,
        same_name_count: same_name.size,
        similar_name_count: similar_name.size
      }
    end

    # Sort by total potential duplicates (most likely duplicates first)
    groups.sort_by { |g| -g[:people].size }
  end
end
