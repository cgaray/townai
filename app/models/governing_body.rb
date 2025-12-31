# frozen_string_literal: true

class GoverningBody < ApplicationRecord
  include NameNormalizable

  belongs_to :town

  has_many :documents, dependent: :nullify
  has_many :attendees, dependent: :nullify
  has_many :people, -> { distinct }, through: :attendees

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: { scope: :town_id }

  scope :by_document_count, -> { order(documents_count: :desc, name: :asc) }

  after_save :reindex_for_search, if: :saved_change_to_name?
  after_destroy :remove_from_search_index

  # Find or create by name (used during extraction)
  # Handles race conditions when multiple processes try to create the same governing body
  #
  # @param name [String] The governing body name
  # @param town [Town] The town to associate with. Required because governing body
  #   uniqueness is scoped to town (same name can exist in different towns).
  # @return [GoverningBody, nil] The found or created governing body, or nil if name is blank
  # @raise [ArgumentError] if town is nil
  def self.find_or_create_by_name(name, town:)
    return nil if name.blank?
    raise ArgumentError, "town is required" if town.nil?

    normalized = normalize_name(name)
    find_or_create_by(normalized_name: normalized, town: town) do |gb|
      gb.name = name.strip
    end
  rescue ActiveRecord::RecordNotUnique
    find_by(normalized_name: normalized, town: town)
  end

  private

  def reindex_for_search
    ReindexSearchJob.perform_later("governing_body", id)
  end

  def remove_from_search_index
    SearchIndexer.remove_governing_body(id)
  end
end
