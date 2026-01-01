class ApplicationController < ActionController::Base
  include Pagy::Backend

  # Require authentication for all actions
  before_action :authenticate_user!

  # Set thread-local Current.user and request info for audit logging
  before_action :set_current_context

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def set_current_context
    Current.user = current_user
    Current.ip_address = request.remote_ip
    Current.user_agent = request.user_agent
  end
end
