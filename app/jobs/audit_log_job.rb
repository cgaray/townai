class AuditLogJob < ApplicationJob
  queue_as :default

  def perform(user:, action:, resource_type:, resource_id: nil, previous_state: nil, new_state: nil, ip_address: nil, params: nil)
    AdminAuditLog.create!(
      user: user,
      action: action,
      resource_type: resource_type,
      resource_id: resource_id,
      previous_state: previous_state,
      new_state: new_state,
      ip_address: ip_address,
      params: params
    )
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to create audit log: #{e.message}"
  end
end
