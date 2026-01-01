# frozen_string_literal: true

class Topic < ApplicationRecord
  belongs_to :document
  has_one :governing_body, through: :document
  has_one :town, through: :governing_body

  enum :action_taken, {
    none: 0,
    approved: 1,
    denied: 2,
    tabled: 3,
    continued: 4
  }, prefix: true

  validates :title, presence: true

  scope :with_actions, -> { where.not(action_taken: :none) }
  scope :ordered, -> { order(:position) }
  scope :recent, -> { joins(:document).merge(Document.order(created_at: :desc)) }
  scope :for_town, ->(town) { joins(:town).where(towns: { id: town.id }) }

  class << self
    # Create Topic records from document's extracted metadata
    # Replaces any existing topics for the document
    def create_from_metadata(document)
      topics_data = document.metadata_field("topics") || []
      return 0 if topics_data.empty?

      # Clear existing topics to avoid duplicates on re-extraction
      document.topics.destroy_all

      created_count = 0
      topics_data.each_with_index do |topic_data, position|
        title = topic_data["title"]
        next if title.blank?

        raw_action = topic_data["action_taken"]
        document.topics.create!(
          title: title,
          summary: topic_data["summary"],
          action_taken: normalize_action(raw_action),
          action_taken_raw: raw_action.presence,
          source_text: topic_data["source_text"],
          position: position
        )
        created_count += 1
      end

      created_count
    end

    # Normalize various action strings to our enum values
    # Handles common municipal meeting terminology from different towns
    def normalize_action(action)
      return :none if action.blank?

      normalized = action.to_s.downcase.strip

      # Check for approval patterns
      if normalized.match?(/\b(approved|passed|accepted|adopted|carried|voted in favor|motion passed|motion carried)\b/)
        :approved
      # Check for denial patterns
      elsif normalized.match?(/\b(denied|rejected|failed|defeated|voted against|motion failed)\b/)
        :denied
      # Check for tabled patterns (temporarily set aside)
      elsif normalized.match?(/\b(tabled|laid on the table|postponed)\b/)
        :tabled
      # Check for continued patterns (deferred to specific date/meeting)
      elsif normalized.match?(/\b(continued|deferred|referred)\b/)
        :continued
      else
        :none
      end
    end
  end

  # Get the meeting date from the parent document
  def meeting_date
    document.metadata_field("meeting_date")
  end

  # Returns true if this topic has a meaningful action (not "none")
  def has_action?
    action_taken.present? && !action_taken_none?
  end

  # Returns 1-indexed position for display in UI
  def display_position
    (position || 0) + 1
  end
end
