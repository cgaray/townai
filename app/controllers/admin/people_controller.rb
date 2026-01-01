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
    @duplicate_groups = find_duplicate_groups
    @last_computed_at = DuplicateSuggestion.last_computed_at

    # Filter by town if specified
    if params[:town_id].present?
      @duplicate_groups = @duplicate_groups.select do |group|
        group[:people].any? { |p| p.town_id.to_s == params[:town_id].to_s }
      end
    end

    @towns = Town.joins(:people).distinct.order(:name)
  end

  def recompute_duplicates
    ComputeDuplicatesJob.perform_later

    AuditLogJob.perform_later(
      user: current_user,
      action: "duplicates_recompute",
      resource_type: "System",
      ip_address: request.remote_ip
    )

    redirect_to duplicates_admin_people_path, notice: "Duplicate detection job queued. Refresh in a moment."
  end

  def merge
    source = Person.find(params[:source_id])
    target = Person.find(params[:target_id])

    source_id = source.id
    source_name = source.name
    merged_count = source.attendees.count
    previous_state = {
      source_attendee_count: source.attendees.count,
      target_attendee_count: target.attendees.count
    }

    # Delete suggestions BEFORE merge to avoid FK constraint errors
    DuplicateSuggestion.involving(source_id).delete_all

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

      redirect_to person_redirect_path(target), notice: "Successfully merged #{source_name} into #{target.name}"
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

  # Build duplicate groups from precomputed DuplicateSuggestion records
  def find_duplicate_groups
    suggestions = DuplicateSuggestion
      .includes(
        person: [ :town, { attendees: :governing_body } ],
        duplicate_person: [ :town, { attendees: :governing_body } ]
      )
      .to_a

    return [] if suggestions.empty?

    build_connected_groups(suggestions)
  end

  # Use Union-Find to group connected people into clusters
  def build_connected_groups(suggestions)
    parent = {}

    # Build union-find structure
    suggestions.each do |s|
      union(parent, s.person_id, s.duplicate_person_id)
    end

    # Collect all person IDs
    person_ids = suggestions.flat_map { |s| [ s.person_id, s.duplicate_person_id ] }.uniq

    # Build people lookup from preloaded suggestions
    people_by_id = {}
    suggestions.each do |s|
      people_by_id[s.person_id] = s.person
      people_by_id[s.duplicate_person_id] = s.duplicate_person
    end

    # Build suggestion lookup for counting match types
    suggestion_lookup = suggestions.each_with_object({}) do |s, hash|
      key = [ s.person_id, s.duplicate_person_id ].sort
      hash[key] = s
    end

    # Group by root and build output
    grouped = person_ids.group_by { |id| find_root(parent, id) }

    grouped.values.map do |ids|
      people = ids.map { |id| people_by_id[id] }.sort_by(&:id)

      exact_count = 0
      similar_count = 0

      people.combination(2).each do |a, b|
        key = [ a.id, b.id ].sort
        if (suggestion = suggestion_lookup[key])
          suggestion.exact? ? exact_count += 1 : similar_count += 1
        end
      end

      {
        normalized_name: people.first.normalized_name,
        people: people,
        same_name_count: exact_count,
        similar_name_count: similar_count
      }
    end.sort_by { |g| -g[:people].size }
  end

  # Union-Find: find root with path compression
  def find_root(parent, id)
    parent[id] ||= id
    parent[id] = find_root(parent, parent[id]) if parent[id] != id
    parent[id]
  end

  # Union-Find: union two sets
  def union(parent, id1, id2)
    root1 = find_root(parent, id1)
    root2 = find_root(parent, id2)
    parent[root1] = root2 if root1 != root2
  end
end
