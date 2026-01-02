module Admin
  class ApiCostsController < BaseController
    def index
      # Consolidate stats into fewer queries
      stats = consolidated_stats
      @total_cost = stats[:total_cost]
      @total_cost_this_month = stats[:total_cost_this_month]
      @average_cost_per_document = stats[:average_cost_per_document]
      @total_calls = stats[:total_calls]
      @successful_calls = stats[:successful_calls]
      @failed_calls = stats[:failed_calls]

      @cost_by_model = ApiCall.cost_by_model
      @recent_calls = ApiCall.recent.includes(:document).limit(50)
    end

    private

    # Consolidate multiple COUNT/SUM queries into a single query
    def consolidated_stats
      beginning_of_month = Time.current.beginning_of_month

      # Use sanitize_sql to safely inject the date parameter
      this_month_case = ApiCall.sanitize_sql_array([
        "COALESCE(SUM(CASE WHEN created_at >= ? THEN cost_credits ELSE 0 END), 0)",
        beginning_of_month
      ])

      result = ApiCall.select(
        "COUNT(*) as total_calls",
        "COALESCE(SUM(cost_credits), 0) as total_cost",
        "#{this_month_case} as total_cost_this_month",
        "COUNT(CASE WHEN status = 'success' THEN 1 END) as successful_calls",
        "COUNT(CASE WHEN status = 'error' THEN 1 END) as failed_calls",
        "COALESCE(AVG(CASE WHEN status = 'success' AND document_id IS NOT NULL THEN cost_credits END), 0) as average_cost_per_document"
      ).take

      {
        total_calls: result.total_calls,
        total_cost: result.total_cost,
        total_cost_this_month: result.total_cost_this_month,
        successful_calls: result.successful_calls,
        failed_calls: result.failed_calls,
        average_cost_per_document: result.average_cost_per_document
      }
    end
  end
end
