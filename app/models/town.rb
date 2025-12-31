# frozen_string_literal: true

class Town < ApplicationRecord
  include NameNormalizable

  has_many :governing_bodies, dependent: :destroy
  has_many :people, dependent: :destroy
  has_many :documents, through: :governing_bodies

  validates :name, :normalized_name, :slug, presence: true
  validates :normalized_name, uniqueness: true
  validates :slug, uniqueness: true, format: { with: /\A[a-z0-9-]+\z/, message: "only allows lowercase letters, numbers, and hyphens" }

  before_validation :generate_slug, if: -> { slug.blank? && name.present? }

  scope :alphabetical, -> { order(name: :asc) }

  def to_param
    slug
  end

  private

  def generate_slug
    base_slug = name.parameterize
    self.slug = base_slug

    # Handle uniqueness conflicts
    counter = 1
    while Town.exists?(slug: slug)
      self.slug = "#{base_slug}-#{counter}"
      counter += 1
    end
  end
end
