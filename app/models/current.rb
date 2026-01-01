# frozen_string_literal: true

# Thread-safe, request-scoped storage for current user and request info.
# Automatically reset between requests by Rails.
#
# Usage:
#   Current.user = current_user
#   Current.ip_address = request.remote_ip
#   puts Current.user&.email
#
# This is set up in ApplicationController#set_current_context
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :ip_address, :user_agent
end
