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
        jobs_pending: SolidQueue::Job.where(finished_at: nil).count,
        jobs_failed: SolidQueue::FailedExecution.count
      }

      @recent_activity = AdminAuditLog.includes(:user)
                                       .order(created_at: :desc)
                                       .limit(10)
    end
  end
end
