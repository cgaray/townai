class CreateDocumentAttendees < ActiveRecord::Migration[8.1]
  def change
    create_table :document_attendees do |t|
      t.references :document, null: false, foreign_key: true
      t.references :attendee, null: false, foreign_key: true
      t.string :role
      t.string :status
      t.text :source_text
      t.timestamps
    end

    add_index :document_attendees, [ :document_id, :attendee_id ], unique: true
  end
end
