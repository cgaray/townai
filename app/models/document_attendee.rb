class DocumentAttendee < ApplicationRecord
  # Status is validated - attendance is universal (present/absent/remote)
  STATUSES = %w[present absent remote].freeze

  belongs_to :document
  belongs_to :attendee

  validates :document_id, uniqueness: { scope: :attendee_id }
  # Role is free-form - varies by committee/town (chair, vice-chair, associate member, etc.)
  validates :status, inclusion: { in: STATUSES, allow_nil: true }
end
