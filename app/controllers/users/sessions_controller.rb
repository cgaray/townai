# frozen_string_literal: true

class Users::SessionsController < Devise::Passwordless::SessionsController
  layout "devise"
end
