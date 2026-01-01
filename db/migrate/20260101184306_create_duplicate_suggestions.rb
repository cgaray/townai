# frozen_string_literal: true

class CreateDuplicateSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :duplicate_suggestions do |t|
      t.references :person, null: false, foreign_key: true, index: true
      t.references :duplicate_person, null: false, foreign_key: { to_table: :people }, index: true
      t.string :match_type, null: false, default: "exact"
      t.integer :similarity_score, null: false, default: 0

      t.timestamps
    end

    # Ensure we don't store the same pair twice
    add_index :duplicate_suggestions, %i[person_id duplicate_person_id], unique: true
  end
end
