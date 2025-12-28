class CreateAttendees < ActiveRecord::Migration[8.1]
  def change
    create_table :attendees do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :primary_governing_body, null: false
      t.json :governing_bodies, default: []
      t.datetime :first_seen_at
      t.datetime :last_seen_at
      t.integer :document_appearances_count, default: 0
      t.references :merged_into, foreign_key: { to_table: :attendees }, null: true
      t.timestamps
    end

    add_index :attendees, [ :normalized_name, :primary_governing_body ], unique: true, name: "index_attendees_on_normalized_name_and_governing_body"
    add_index :attendees, :name
    add_index :attendees, :document_appearances_count
  end
end
