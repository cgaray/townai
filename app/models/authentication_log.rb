class AuthenticationLog < ApplicationRecord
  belongs_to :user, optional: true

  validates :action, presence: true

  ACTION_TYPES = %w[login_success login_failed logout magic_link_used magic_link_failed password_reset_requested password_reset_completed].freeze

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :successful, -> { where(action: "login_success") }
  scope :failed, -> { where(action: "login_failed") }
  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..) }

  # Hash email using SHA256 for privacy
  def self.hash_email(email)
    Digest::SHA256.hexdigest(email.to_s.downcase)
  end

  # Check if this was a successful login
  def success?
    action == "login_success"
  end

  # Check if this was a failed attempt
  def failed?
    action.in?(%w[login_failed magic_link_failed])
  end

  # Get display name for action
  def action_display_name
    case action
    when "login_success" then "Successful login"
    when "login_failed" then "Failed login"
    when "logout" then "Logged out"
    when "magic_link_used" then "Magic link used"
    when "magic_link_failed" then "Magic link failed"
    when "password_reset_requested" then "Password reset requested"
    when "password_reset_completed" then "Password reset completed"
    else action.humanize
    end
  end
end
