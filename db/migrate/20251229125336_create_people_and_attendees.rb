# frozen_string_literal: true

# Squashed migration for People and Attendees feature
# Creates the Person model (merged/visible entity) and Attendee model (raw extraction data)
class CreatePeopleAndAttendees < ActiveRecord::Migration[8.1]
  def change
    # Create people table (the merged/visible entity)
    create_table :people do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.integer :document_appearances_count, default: 0

      t.timestamps
    end

    add_index :people, :normalized_name
    add_index :people, :name
    add_index :people, :document_appearances_count

    # Create attendees table (raw extraction data, belongs to a Person)
    create_table :attendees do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :governing_body, null: false
      t.references :person, foreign_key: true, index: true

      t.timestamps
    end

    add_index :attendees, :name
    add_index :attendees, [ :normalized_name, :governing_body ],
              unique: true,
              name: "index_attendees_on_normalized_name_and_governing_body"

    # Create document_attendees join table
    create_table :document_attendees do |t|
      t.references :document, null: false, foreign_key: true, index: true
      t.references :attendee, null: false, foreign_key: true, index: true
      t.string :role
      t.string :status
      t.text :source_text

      t.timestamps
    end

    add_index :document_attendees, [ :document_id, :attendee_id ], unique: true
  end
end
