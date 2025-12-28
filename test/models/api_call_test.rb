require "test_helper"

class ApiCallTest < ActiveSupport::TestCase
  setup do
    @document = documents(:complete_agenda)
  end

  test "should be valid with required attributes" do
    api_call = ApiCall.new(
      provider: "openrouter",
      model: "google/gemini-2.0-flash-001",
      operation: "extract_metadata",
      status: "success"
    )
    assert api_call.valid?
  end

  test "should require provider" do
    api_call = ApiCall.new(model: "test", operation: "test", status: "success")
    assert_not api_call.valid?
    assert_includes api_call.errors[:provider], "can't be blank"
  end

  test "should require model" do
    api_call = ApiCall.new(provider: "test", operation: "test", status: "success")
    assert_not api_call.valid?
    assert_includes api_call.errors[:model], "can't be blank"
  end

  test "should require operation" do
    api_call = ApiCall.new(provider: "test", model: "test", status: "success")
    assert_not api_call.valid?
    assert_includes api_call.errors[:operation], "can't be blank"
  end

  test "should require status" do
    api_call = ApiCall.new(provider: "test", model: "test", operation: "test")
    assert_not api_call.valid?
    assert_includes api_call.errors[:status], "can't be blank"
  end

  test "document association is optional" do
    api_call = ApiCall.new(
      provider: "openrouter",
      model: "test-model",
      operation: "test",
      status: "success"
    )
    assert api_call.valid?
    assert_nil api_call.document
  end

  test "belongs to document" do
    api_call = ApiCall.create!(
      document: @document,
      provider: "openrouter",
      model: "test-model",
      operation: "extract_metadata",
      status: "success"
    )
    assert_equal @document, api_call.document
  end

  test "successful scope returns only successful calls" do
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success")
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "error")

    successful = ApiCall.successful
    assert successful.all? { |c| c.status == "success" }
  end

  test "failed scope returns only failed calls" do
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success")
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "error")

    failed = ApiCall.failed
    assert failed.all? { |c| c.status == "error" }
  end

  test "recent scope orders by created_at desc" do
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", created_at: 1.day.ago)
    newer = ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", created_at: Time.current)

    recent = ApiCall.recent
    assert_equal newer, recent.first
  end

  test "this_month scope returns only current month calls" do
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", created_at: 2.months.ago)
    current = ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", created_at: Time.current)

    this_month = ApiCall.this_month
    assert_includes this_month, current
    assert_equal 1, this_month.count
  end

  test "total_cost sums cost_credits" do
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", cost_credits: 0.001)
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", cost_credits: 0.002)

    assert_in_delta 0.003, ApiCall.total_cost, 0.0001
  end

  test "total_cost returns 0 when no calls" do
    ApiCall.delete_all
    assert_equal 0, ApiCall.total_cost
  end

  test "total_cost_this_month sums only current month" do
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", cost_credits: 0.001, created_at: 2.months.ago)
    ApiCall.create!(provider: "test", model: "test", operation: "test", status: "success", cost_credits: 0.002, created_at: Time.current)

    assert_in_delta 0.002, ApiCall.total_cost_this_month, 0.0001
  end

  test "average_cost_per_document calculates average for successful calls with documents" do
    ApiCall.create!(document: @document, provider: "test", model: "test", operation: "test", status: "success", cost_credits: 0.001)
    ApiCall.create!(document: @document, provider: "test", model: "test", operation: "test", status: "success", cost_credits: 0.003)

    assert_in_delta 0.002, ApiCall.average_cost_per_document, 0.0001
  end

  test "cost_by_model groups costs by model" do
    ApiCall.create!(provider: "test", model: "model-a", operation: "test", status: "success", cost_credits: 0.001)
    ApiCall.create!(provider: "test", model: "model-a", operation: "test", status: "success", cost_credits: 0.001)
    ApiCall.create!(provider: "test", model: "model-b", operation: "test", status: "success", cost_credits: 0.002)

    cost_by_model = ApiCall.cost_by_model
    assert_in_delta 0.002, cost_by_model["model-a"], 0.0001
    assert_in_delta 0.002, cost_by_model["model-b"], 0.0001
  end

  test "cost_usd returns cost_credits (1:1 ratio)" do
    api_call = ApiCall.new(cost_credits: 0.00123)
    assert_equal 0.00123, api_call.cost_usd
  end
end
