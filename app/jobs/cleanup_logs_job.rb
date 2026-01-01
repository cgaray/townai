# frozen_string_literal: true

# Cleans up old audit and event logs based on retention policies:
# - AdminAuditLog: 90 days
# - AuthenticationLog: 90 days
# - DocumentEventLog: 1 year
#
# Runs daily via config/recurring.yml
class CleanupLogsJob < ApplicationJob
  queue_as :default

  RETENTION_POLICIES = {
    "AdminAuditLog" => 90.days,
    "AuthenticationLog" => 90.days,
    "DocumentEventLog" => 1.year
  }.freeze

  def perform
    results = {}

    RETENTION_POLICIES.each do |model_name, retention_period|
      model = model_name.constantize
      cutoff_date = retention_period.ago

      count = model.where("created_at < ?", cutoff_date).delete_all
      results[model_name] = count

      Rails.logger.info("CleanupLogsJob: Deleted #{count} #{model_name} records older than #{cutoff_date}")
    end

    results
  end
end
