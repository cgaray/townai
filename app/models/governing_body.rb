# frozen_string_literal: true

class GoverningBody < ApplicationRecord
  has_many :documents, dependent: :nullify
  has_many :attendees, dependent: :nullify
  has_many :people, -> { distinct }, through: :attendees

  validates :name, :normalized_name, presence: true
  validates :normalized_name, uniqueness: true

  before_validation :set_normalized_name, if: -> { name.present? && normalized_name.blank? }

  scope :by_document_count, -> { order(documents_count: :desc, name: :asc) }

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

  def self.normalize_name(name)
    name.to_s.downcase.squish
  end

  private

  def set_normalized_name
    self.normalized_name = self.class.normalize_name(name)
  end
end
