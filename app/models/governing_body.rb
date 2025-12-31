# frozen_string_literal: true

class GoverningBody < ApplicationRecord
  include NameNormalizable

  has_many :documents, dependent: :nullify
  has_many :attendees, dependent: :nullify
  has_many :people, -> { distinct }, through: :attendees

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: true

  scope :by_document_count, -> { order(documents_count: :desc, name: :asc) }

  after_save :reindex_for_search, if: :saved_change_to_name?
  after_destroy :remove_from_search_index

  # Find or create by name (used during extraction)
  # Handles race conditions when multiple processes try to create the same governing body
  def self.find_or_create_by_name(name)
    return nil if name.blank?

    normalized = normalize_name(name)
    find_or_create_by(normalized_name: normalized) do |gb|
      gb.name = name.strip
    end
  rescue ActiveRecord::RecordNotUnique
    find_by(normalized_name: normalized)
  end

  private

  def reindex_for_search
    SearchIndexer.index_governing_body(self)
  end

  def remove_from_search_index
    SearchIndexer.remove_governing_body(id)
  end
end
