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
  end
end
