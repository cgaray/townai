# frozen_string_literal: true

module Admin
  class SystemController < BaseController
    def index
      @search_stats = search_stats
      @cache_stats = cache_stats
      @queue_stats = queue_stats
    end

    def rebuild_search
      RebuildSearchIndexJob.perform_later

      AuditLogJob.perform_later(
        user: current_user,
        action: "search_rebuild",
        resource_type: "System",
        new_state: { timestamp: Time.current.iso8601 }.to_json,
        ip_address: request.remote_ip
      )

      redirect_to admin_system_index_path, notice: "Search index rebuild started. This may take a few minutes."
    end

    def clear_cache
      Rails.cache.clear

      AuditLogJob.perform_later(
        user: current_user,
        action: "cache_clear",
        resource_type: "System",
        new_state: { timestamp: Time.current.iso8601 }.to_json,
        ip_address: request.remote_ip
      )

      redirect_to admin_system_index_path, notice: "Cache cleared successfully."
    end

    private

    def search_stats
      sql = "SELECT entity_type, COUNT(*) as count FROM search_entries GROUP BY entity_type ORDER BY entity_type"
      results = ActiveRecord::Base.connection.select_all(sql)

      stats = {}
      total = 0
      results.each do |row|
        stats[row["entity_type"]] = row["count"]
        total += row["count"]
      end
      stats["total"] = total
      stats
    rescue ActiveRecord::StatementInvalid
      { "error" => "Search index not available" }
    end

    def cache_stats
      if defined?(SolidCache::Entry)
        { "entries" => SolidCache::Entry.count }
      else
        { "entries" => "N/A" }
      end
    rescue StandardError
      { "entries" => "Unknown" }
    end

    def queue_stats
      {
        "pending" => SolidQueue::Job.where(finished_at: nil).count,
        "failed" => SolidQueue::FailedExecution.count,
        "processes" => SolidQueue::Process.count
      }
    rescue StandardError
      { "pending" => "N/A", "failed" => "N/A", "processes" => "N/A" }
    end
  end
end
