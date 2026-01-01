module Admin
  class ApiCostsController < BaseController
    def index
      @total_cost = ApiCall.total_cost
      @total_cost_this_month = ApiCall.total_cost_this_month
      @average_cost_per_document = ApiCall.average_cost_per_document
      @total_calls = ApiCall.count
      @successful_calls = ApiCall.successful.count
      @failed_calls = ApiCall.failed.count
      @cost_by_model = ApiCall.cost_by_model
      @recent_calls = ApiCall.recent.includes(:document).limit(50)
    end
  end
end
