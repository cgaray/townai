class ApiCall < ApplicationRecord
  belongs_to :document, optional: true

  validates :provider, :model, :operation, :status, presence: true

  scope :successful, -> { where(status: "success") }
  scope :failed, -> { where(status: "error") }
  scope :recent, -> { order(created_at: :desc) }
  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..) }
  scope :by_provider, ->(provider) { where(provider: provider) }
  scope :by_model, ->(model) { where(model: model) }

  def self.total_cost
    sum(:cost_credits) || 0
  end

  def self.total_cost_this_month
    this_month.sum(:cost_credits) || 0
  end

  def self.average_cost_per_document
    successful.where.not(document_id: nil).average(:cost_credits) || 0
  end

  def self.cost_by_model
    successful.group(:model).sum(:cost_credits)
  end

  # Cost in USD (1 credit = $1 USD on OpenRouter)
  def cost_usd
    cost_credits
  end
end
