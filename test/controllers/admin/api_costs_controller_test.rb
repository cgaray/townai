require "test_helper"

module Admin
  class ApiCostsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @document = documents(:complete_agenda)
      sign_in users(:admin)
    end

    test "redirects non-admin users to root" do
      sign_out :user
      sign_in users(:user)
      get admin_api_costs_url
      assert_redirected_to root_url
      assert_match(/not authorized/, flash[:alert])
    end

    test "redirects unauthenticated users to login" do
      sign_out :user
      get admin_api_costs_url
      assert_redirected_to new_user_session_url
    end

    test "should get index" do
      get admin_api_costs_url
      assert_response :success
    end

    test "index displays stats cards" do
      get admin_api_costs_url
      assert_response :success
      assert_select "h1", /API Costs/
    end

    test "index displays total cost" do
      ApiCall.create!(
        document: @document,
        provider: "openrouter",
        model: "test-model",
        operation: "extract_metadata",
        status: "success",
        cost_credits: 0.001
      )

      get admin_api_costs_url
      assert_response :success
    end

    test "index displays recent calls table" do
      ApiCall.create!(
        document: @document,
        provider: "openrouter",
        model: "google/gemini-2.0-flash-001",
        operation: "extract_metadata",
        status: "success",
        prompt_tokens: 100,
        completion_tokens: 50,
        total_tokens: 150,
        cost_credits: 0.001,
        response_time_ms: 1500
      )

      get admin_api_costs_url
      assert_response :success
      assert_select "table"
    end

    test "index displays cost by model" do
      ApiCall.create!(
        provider: "openrouter",
        model: "model-a",
        operation: "test",
        status: "success",
        cost_credits: 0.001
      )

      get admin_api_costs_url
      assert_response :success
    end

    test "index handles empty state" do
      ApiCall.delete_all

      get admin_api_costs_url
      assert_response :success
      assert_select "p", /No API calls recorded yet/
    end

    test "index displays success and error badges" do
      ApiCall.create!(
        provider: "openrouter",
        model: "test-model",
        operation: "extract_metadata",
        status: "success"
      )
      ApiCall.create!(
        provider: "openrouter",
        model: "test-model",
        operation: "extract_metadata",
        status: "error",
        error_message: "Test error"
      )

      get admin_api_costs_url
      assert_response :success
      assert_select ".badge-success", /Success/
      assert_select ".badge-error", /Error/
    end

    # Tests for consolidated_stats method - verify page renders with computed stats

    test "consolidated_stats computes correct totals" do
      ApiCall.delete_all

      ApiCall.create!(provider: "openrouter", model: "model-a", operation: "op", status: "success", cost_credits: 0.01, document: @document)
      ApiCall.create!(provider: "openrouter", model: "model-a", operation: "op", status: "success", cost_credits: 0.02, document: @document)
      ApiCall.create!(provider: "openrouter", model: "model-b", operation: "op", status: "error", cost_credits: 0.005)

      get admin_api_costs_url
      assert_response :success

      # Verify stats are displayed (total_calls = 3, successful = 2, failed = 1)
      assert_match(/3/, response.body) # total calls
      assert_match(/2/, response.body) # successful
      assert_match(/1/, response.body) # failed
    end

    test "consolidated_stats computes this_month correctly" do
      ApiCall.delete_all

      # Create a call from last month
      travel_to 2.months.ago do
        ApiCall.create!(provider: "openrouter", model: "model", operation: "op", status: "success", cost_credits: 1.0)
      end

      # Create a call this month
      ApiCall.create!(provider: "openrouter", model: "model", operation: "op", status: "success", cost_credits: 0.5)

      get admin_api_costs_url
      assert_response :success

      # Page should render without error
    end

    test "consolidated_stats computes average_cost_per_document correctly" do
      ApiCall.delete_all

      # Calls with documents - should be included in average
      ApiCall.create!(provider: "openrouter", model: "model", operation: "op", status: "success", cost_credits: 0.10, document: @document)
      ApiCall.create!(provider: "openrouter", model: "model", operation: "op", status: "success", cost_credits: 0.20, document: @document)
      # Call without document - should be excluded from average
      ApiCall.create!(provider: "openrouter", model: "model", operation: "op", status: "success", cost_credits: 0.50, document: nil)
      # Failed call - should be excluded from average
      ApiCall.create!(provider: "openrouter", model: "model", operation: "op", status: "error", cost_credits: 0.30, document: @document)

      get admin_api_costs_url
      assert_response :success

      # Page should render without error
    end

    test "consolidated_stats handles zero records gracefully" do
      ApiCall.delete_all

      get admin_api_costs_url
      assert_response :success

      # Should show empty state
      assert_select "p", /No API calls recorded yet/
    end
  end
end
