class DocumentAttendee < ApplicationRecord
  ROLES = %w[member chair clerk staff public].freeze
  STATUSES = %w[present absent remote].freeze

  belongs_to :document
  belongs_to :attendee, counter_cache: :document_appearances_count

  validates :document_id, uniqueness: { scope: :attendee_id }
  validates :role, inclusion: { in: ROLES, allow_nil: true }
  validates :status, inclusion: { in: STATUSES, allow_nil: true }
end
