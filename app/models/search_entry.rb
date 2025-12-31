# frozen_string_literal: true

# SearchEntry provides an interface to the FTS5 search_entries virtual table.
# This model is read-only for searching; use SearchIndexer service to populate.
class SearchEntry < ApplicationRecord
  self.table_name = "search_entries"
  self.primary_key = "rowid"

  VALID_ENTITY_TYPES = %w[document topic person governing_body].freeze

  # Search across all indexed content
  # @param query [String] the search query
  # @param types [Array<String>] optional filter by entity types
  # @param limit [Integer] max results to return
  # @return [Array<Hash>] search results with highlighted snippets
  def self.search(query, types: nil, limit: 20)
    return [] if query.blank?

    # Escape special FTS5 characters and add prefix matching
    sanitized_query = sanitize_fts_query(query)
    return [] if sanitized_query.blank?

    type_filter = if types.present?
      valid_types = Array(types) & VALID_ENTITY_TYPES
      return [] if valid_types.empty?
      "AND entity_type IN (#{valid_types.map { |t| connection.quote(t) }.join(', ')})"
    else
      ""
    end

    sql = <<~SQL
      SELECT
        rowid,
        entity_type,
        entity_id,
        title,
        subtitle,
        url,
        snippet(search_entries, 4, '<mark>', '</mark>', '...', 32) AS snippet,
        bm25(search_entries) AS rank
      FROM search_entries
      WHERE search_entries MATCH ?
      #{type_filter}
      ORDER BY rank
      LIMIT ?
    SQL

    results = connection.select_all(
      sanitize_sql_array([ sql, sanitized_query, limit ])
    )

    results.map do |row|
      {
        id: row["rowid"],
        entity_type: row["entity_type"],
        entity_id: row["entity_id"].to_i,
        title: row["title"],
        subtitle: row["subtitle"],
        url: row["url"],
        snippet: self.sanitize_snippet(row["snippet"]),
        rank: row["rank"]
      }
    end
  end

  # Count results by entity type for filter badges
  # @param query [String] the search query
  # @return [Hash] counts by entity type
  def self.counts_by_type(query)
    return {} if query.blank?

    sanitized_query = sanitize_fts_query(query)
    return {} if sanitized_query.blank?

    sql = <<~SQL
      SELECT entity_type, COUNT(*) as count
      FROM search_entries
      WHERE search_entries MATCH ?
      GROUP BY entity_type
    SQL

    results = connection.select_all(
      sanitize_sql_array([ sql, sanitized_query ])
    )

    results.each_with_object({}) do |row, hash|
      hash[row["entity_type"]] = row["count"]
    end
  end

  # Clear all entries (used before reindexing)
  def self.clear_all!
    connection.execute("DELETE FROM search_entries")
  end

  # Clear entries for a specific entity
  def self.clear_entity!(entity_type, entity_id)
    connection.execute(
      sanitize_sql_array([
        "DELETE FROM search_entries WHERE entity_type = ? AND entity_id = ?",
        entity_type,
        entity_id.to_s
      ])
    )
  end

  # Insert a new search entry
  def self.insert_entry!(entity_type:, entity_id:, title:, subtitle:, content:, url:)
    connection.execute(
      sanitize_sql_array([
        "INSERT INTO search_entries (entity_type, entity_id, title, subtitle, content, url) VALUES (?, ?, ?, ?, ?, ?)",
        entity_type,
        entity_id.to_s,
        title.to_s,
        subtitle.to_s,
        content.to_s,
        url.to_s
      ])
    )
  end

  private

  # Sanitize snippet HTML to only allow <mark> tags (prevents XSS)
  def self.sanitize_snippet(snippet)
    return nil if snippet.blank?

    ActionController::Base.helpers.sanitize(snippet, tags: %w[mark])
  end

  # Sanitize query for FTS5 syntax
  # Escapes special characters and adds prefix matching for better UX
  def self.sanitize_fts_query(query)
    # Remove FTS5 special characters and operators that could break the query
    cleaned = query.to_s
      .gsub(/["\*\(\)\{\}\[\]:^~\-\+]/, " ")
      .gsub(/\b(AND|OR|NOT|NEAR)\b/i, " ")
      .strip

    # Split into words and add prefix matching to each word
    words = cleaned.split(/\s+/).reject(&:blank?)
    return nil if words.empty?

    # Use prefix matching (*) on last word for typeahead feel
    # Quote each term to handle special cases
    words.map.with_index do |word, i|
      if i == words.length - 1
        "\"#{word}\"*"
      else
        "\"#{word}\""
      end
    end.join(" ")
  end
end
