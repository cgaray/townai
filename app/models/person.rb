# frozen_string_literal: true

class Person < ApplicationRecord
  include NameNormalizable

  has_many :attendees, dependent: :restrict_with_error
  has_many :document_attendees, through: :attendees
  has_many :documents, -> { distinct }, through: :document_attendees

  validates :name, :normalized_name, presence: true

  scope :by_appearances, -> { order(document_appearances_count: :desc, name: :asc) }

  after_save :reindex_for_search, if: :saved_change_to_name?
  after_destroy :remove_from_search_index

  # Strip titles (Mr., Dr., Jr., etc.) when normalizing person names
  def self.strip_titles_on_normalize?
    true
  end

  # Get all governing bodies this person has been seen in (as GoverningBody records)
  def governing_bodies
    GoverningBody.joins(:attendees).where(attendees: { person_id: id }).distinct
  end

  # Get all governing body names (extracted strings) for display
  def governing_body_names
    attendees.pluck(:governing_body_extracted).uniq.compact
  end

  # Get the most common governing body (primary affiliation)
  # Uses preloaded data when available to avoid N+1 queries
  def primary_governing_body
    return @primary_governing_body if defined?(@primary_governing_body)

    @primary_governing_body = if attendees.loaded?
      # Use in-memory calculation when preloaded
      attendees
        .select(&:governing_body)
        .group_by(&:governing_body)
        .max_by { |_, v| v.size }
        &.first
    else
      # Fall back to database query
      attendees
        .joins(:governing_body)
        .group("governing_bodies.id")
        .order(Arel.sql("COUNT(*) DESC"))
        .first&.governing_body
    end
  end

  # Get date range from document metadata
  def first_seen_at
    @first_seen_at ||= compute_seen_dates[:first]
  end

  def last_seen_at
    @last_seen_at ||= compute_seen_dates[:last]
  end

  # Get all roles this person has held across all appearances
  def roles_held
    if document_attendees.loaded?
      document_attendees.filter_map(&:role).uniq
    else
      document_attendees.where.not(role: nil).distinct.pluck(:role)
    end
  end

  # Find people who frequently appear in the same documents
  # Includes associations to avoid N+1 when displaying primary_governing_body
  def co_people(limit: 10)
    doc_ids_subquery = document_attendees.select(:document_id)

    Person
      .includes(attendees: :governing_body)
      .joins(attendees: :document_attendees)
      .where(document_attendees: { document_id: doc_ids_subquery })
      .where.not(id: id)
      .group(:id)
      .order(Arel.sql("COUNT(document_attendees.id) DESC"))
      .limit(limit)
  end

  # Find potential duplicate people for merge suggestions
  # Returns a hash with :same_name and :similar_name arrays
  # Includes associations to avoid N+1 when displaying primary_governing_body
  def potential_duplicates
    same_name = Person
      .includes(attendees: :governing_body)
      .where(normalized_name: normalized_name)
      .where.not(id: id)

    # Optimize: filter by name length first (Levenshtein distance of 2 means max 2 char difference)
    min_length = [ normalized_name.length - 2, 1 ].max
    max_length = normalized_name.length + 2

    similar_name = Person
      .includes(attendees: :governing_body)
      .where.not(id: id)
      .where.not(normalized_name: normalized_name)
      .where("LENGTH(normalized_name) BETWEEN ? AND ?", min_length, max_length)
      .limit(100)
      .select { |p| Attendee.levenshtein_distance(normalized_name, p.normalized_name) <= 2 }

    {
      same_name: same_name,
      similar_name: similar_name
    }
  end

  # Recalculate the counter cache from document_attendees
  def update_appearances_count!
    update_column(:document_appearances_count, document_attendees.count)
  end

  private

  def compute_seen_dates
    dates = documents.filter_map do |doc|
      date_str = doc.metadata_field("meeting_date")
      next if date_str.blank?

      begin
        Date.parse(date_str)
      rescue ArgumentError, TypeError
        nil
      end
    end

    first, last = dates.minmax
    { first: first, last: last }
  end

  def reindex_for_search
    ReindexSearchJob.perform_later("person", id)
  end

  def remove_from_search_index
    SearchIndexer.remove_person(id)
  end
end
