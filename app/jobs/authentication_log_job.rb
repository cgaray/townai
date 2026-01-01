class AuthenticationLogJob < ApplicationJob
  queue_as :default

  def perform(user_id: nil, action:, email: nil, ip_address: nil, user_agent: nil)
    email_hash = email.present? ? AuthenticationLog.hash_email(email) : nil

    AuthenticationLog.create!(
      user_id: user_id,
      action: action,
      email_hash: email_hash,
      ip_address: ip_address,
      user_agent: user_agent
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create authentication log: #{e.message}"
  end
end
