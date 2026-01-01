# frozen_string_literal: true

class Users::MagicLinksController < Devise::MagicLinksController
  # GET /users/magic_link?token=...
  # This is called when a user clicks the magic link in their email
  def show
    # Track whether authentication succeeded before any potential errors
    @auth_succeeded = false

    super do |resource|
      @auth_succeeded = true
      log_successful_login(resource)
    end
  rescue StandardError
    # Only log failed login if authentication itself failed (not a downstream error)
    log_failed_login unless @auth_succeeded
    raise
  end

  private

  def log_successful_login(resource)
    AuthenticationLogJob.perform_later(
      user_id: resource.id,
      action: "login_success",
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end

  def log_failed_login
    AuthenticationLogJob.perform_later(
      action: "login_failed",
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
end
