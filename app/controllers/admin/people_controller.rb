# frozen_string_literal: true

# TODO: Add authentication before deploying to production
# Options: HTTP Basic Auth, Devise admin user, or IP restriction
class Admin::PeopleController < ApplicationController
  def merge
    source = Person.find(params[:source_id])
    target = Person.find(params[:target_id])

    merger = ::PersonMerger.new(source: source, target: target)

    if merger.merge!
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

    unmerger = ::PersonUnmerger.new(attendee: attendee)

    if unmerger.unmerge!
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
end
