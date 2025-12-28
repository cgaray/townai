class Attendee < ApplicationRecord
  has_many :document_attendees, dependent: :destroy
  has_many :documents, through: :document_attendees

  belongs_to :merged_into, class_name: "Attendee", optional: true
  has_many :merged_attendees, class_name: "Attendee", foreign_key: :merged_into_id

  validates :name, :normalized_name, :primary_governing_body, presence: true
  validates :normalized_name, uniqueness: { scope: :primary_governing_body }
  validate :cannot_merge_into_self

  def cannot_merge_into_self
    errors.add(:merged_into, "cannot be self") if merged_into_id.present? && merged_into_id == id
  end

  before_validation :set_normalized_name, if: -> { name.present? && normalized_name.blank? }
  before_validation :set_governing_bodies, if: -> { primary_governing_body.present? && governing_bodies.blank? }

  scope :active, -> { where(merged_into_id: nil) }
  scope :merged, -> { where.not(merged_into_id: nil) }
  scope :by_appearances, -> { order(document_appearances_count: :desc) }

  # Normalize a name for matching purposes
  def self.normalize_name(name)
    name.to_s
        .downcase
        .gsub(/\b(mr|mrs|ms|dr|jr|sr|ii|iii|iv)\.?\b/i, "")
        .gsub(/[-]/, " ")  # Convert hyphens to spaces
        .gsub(/[^a-z\s]/i, "")  # Remove non-alpha except spaces
        .squish
  end

  # Calculate Levenshtein distance between two strings
  def self.levenshtein_distance(s1, s2)
    m = s1.length
    n = s2.length
    return n if m.zero?
    return m if n.zero?

    d = Array.new(m + 1) { Array.new(n + 1, 0) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }

    (1..n).each do |j|
      (1..m).each do |i|
        cost = s1[i - 1] == s2[j - 1] ? 0 : 1
        d[i][j] = [ d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost ].min
      end
    end

    d[m][n]
  end

  # Find potential duplicates for this attendee
  # Returns a hash with :same_name_different_body (ActiveRecord::Relation) and :similar_name (Array)
  def potential_duplicates
    empty_result = { same_name_different_body: Attendee.none, similar_name: [] }
    return empty_result if merged_into_id.present?

    same_name_different_body = Attendee.active
                                        .where(normalized_name: normalized_name)
                                        .where.not(id: id)
                                        .where.not(primary_governing_body: primary_governing_body)

    # Optimize: filter by name length first (Levenshtein distance of 2 means max 2 char difference)
    # This reduces the number of records loaded into memory for comparison
    min_length = [ normalized_name.length - 2, 1 ].max
    max_length = normalized_name.length + 2

    similar_name = Attendee.active
                           .where.not(id: id)
                           .where.not(normalized_name: normalized_name)
                           .where("LENGTH(normalized_name) BETWEEN ? AND ?", min_length, max_length)
                           .select { |a| self.class.levenshtein_distance(normalized_name, a.normalized_name) <= 2 }

    {
      same_name_different_body: same_name_different_body,
      similar_name: similar_name
    }
  end

  # Get the canonical (non-merged) version of this attendee
  # Follows the merge chain to find the ultimate target
  # Includes cycle detection to prevent infinite loops from data corruption
  def canonical
    return self unless merged_into.present?

    # Follow the chain to handle deep merges (A->B->C)
    # Use a Set to detect cycles and prevent infinite loops
    seen = Set.new([ id ])
    current = merged_into

    while current.merged_into.present?
      break if seen.include?(current.id) # Cycle detected, stop here
      seen << current.id
      current = current.merged_into
    end

    current
  end

  # Check if this attendee has been merged
  def merged?
    merged_into_id.present?
  end

  # Get all roles this attendee has held
  # Uses the preloaded association if available to avoid N+1 queries
  def roles_held
    if document_attendees.loaded?
      document_attendees.filter_map(&:role).uniq
    else
      document_attendees.where.not(role: nil).distinct.pluck(:role)
    end
  end

  # Get co-attendees (people who have appeared in meetings with this attendee)
  def co_attendees(limit: 10)
    Attendee.active
            .joins(:document_attendees)
            .where(document_attendees: { document_id: document_ids })
            .where.not(id: id)
            .group(:id)
            .order(Arel.sql("COUNT(*) DESC"))
            .limit(limit)
  end

  # Update first/last seen dates based on documents
  def update_seen_dates!
    dates = documents.filter_map { |d| d.metadata_field("meeting_date") }
                     .map { |d| Date.parse(d) rescue nil }
                     .compact

    return if dates.empty?

    update!(
      first_seen_at: dates.min,
      last_seen_at: dates.max
    )
  end

  private

  def set_normalized_name
    self.normalized_name = self.class.normalize_name(name)
  end

  def set_governing_bodies
    self.governing_bodies = [ primary_governing_body ]
  end
end
