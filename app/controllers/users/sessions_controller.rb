# frozen_string_literal: true

class Users::SessionsController < Devise::Passwordless::SessionsController
  layout "devise"

  # The parent's create action sends magic link emails - we just call super
  # Magic link authentication happens in Users::MagicLinksController#show

  def destroy
    log_logout if user_signed_in?
    signed_out = (Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name))
    set_flash_message!(:notice, :signed_out) if signed_out
    redirect_to after_sign_out_path_for(resource_name)
  end

  private

  def log_logout
    AuthenticationLogJob.perform_later(
      user_id: current_user.id,
      action: "logout",
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
end
