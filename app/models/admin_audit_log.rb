class AdminAuditLog < ApplicationRecord
  belongs_to :user

  validates :user, :action, :resource_type, presence: true

  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_resource, ->(type, id) { where(resource_type: type, resource_id: id) }

  # Convert action_taken enum values to display names
  def self.action_types
    %w[user_create user_update user_delete user_role_change
       person_merge person_unmerge person_link person_unlink
       document_retry document_reextract document_delete document_update
       topic_update topic_delete
       index_rebuild cache_clear system_action]
  end

  # Format previous/new state from JSON
  def previous_state_parsed
    JSON.parse(previous_state) if previous_state.present?
  end

  def new_state_parsed
    JSON.parse(new_state) if new_state.present?
  end

  def params_parsed
    JSON.parse(params) if params.present?
  end
end
