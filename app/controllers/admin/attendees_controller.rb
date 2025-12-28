# TODO: Add authentication before deploying to production
# Options: HTTP Basic Auth, Devise admin user, or IP restriction
class Admin::AttendeesController < ApplicationController
  def merge
    source = Attendee.find(params[:source_id])
    target = Attendee.find(params[:target_id])

    merger = AttendeeMerger.new(source: source, target: target)

    if merger.merge!
      redirect_to attendee_path(target), notice: "Successfully merged #{source.name} into #{target.name}"
    else
      redirect_to attendee_path(source), alert: "Merge failed: #{merger.errors.join(', ')}"
    end
  rescue ActiveRecord::RecordNotFound
    redirect_to attendees_path, alert: "Attendee not found"
  end
end
