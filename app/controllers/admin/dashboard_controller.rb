# frozen_string_literal: true

module Admin
  class DashboardController < BaseController
    def index
      @stats = {
        documents: Document.count,
        documents_failed: Document.failed.count,
        documents_pending: Document.where(status: [ :pending, :extracting_text, :extracting_metadata ]).count,
        people: Person.count,
        users: User.count,
        topics: Topic.count,
        jobs_pending: queue_stats[:pending],
        jobs_failed: queue_stats[:failed]
      }

      @recent_activity = AdminAuditLog.includes(:user)
                                       .order(created_at: :desc)
                                       .limit(10)
    end

    private

    def queue_stats
      {
        pending: SolidQueue::Job.where(finished_at: nil).count,
        failed: SolidQueue::FailedExecution.count
      }
    rescue ActiveRecord::StatementInvalid
      { pending: 0, failed: 0 }
    end
  end
end
