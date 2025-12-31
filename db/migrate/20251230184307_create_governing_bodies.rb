class CreateGoverningBodies < ActiveRecord::Migration[8.1]
  def change
    create_table :governing_bodies do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.integer :documents_count, default: 0
      t.timestamps
    end

    add_index :governing_bodies, :normalized_name, unique: true
    add_index :governing_bodies, :name

    # Add FK to documents
    add_reference :documents, :governing_body, foreign_key: true, null: true

    # Add FK to attendees and rename existing string column for clarity
    add_reference :attendees, :governing_body, foreign_key: true, null: true
    rename_column :attendees, :governing_body, :governing_body_extracted
  end
end
