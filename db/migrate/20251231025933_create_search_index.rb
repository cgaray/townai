class CreateSearchIndex < ActiveRecord::Migration[8.1]
  def up
    # Create FTS5 virtual table for full-text search
    # Using porter stemmer for better word matching and unicode61 tokenizer
    execute <<~SQL
      CREATE VIRTUAL TABLE search_entries USING fts5(
        entity_type,
        entity_id UNINDEXED,
        title,
        subtitle,
        content,
        url UNINDEXED,
        tokenize='porter unicode61'
      );
    SQL
  end

  def down
    execute "DROP TABLE IF EXISTS search_entries"
  end
end
