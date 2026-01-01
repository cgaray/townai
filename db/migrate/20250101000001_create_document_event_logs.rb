class CreateDocumentEventLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :document_event_logs do |t|
      t.references :document, null: false, foreign_key: true
      t.string :event_type, null: false
      t.text :metadata
      t.timestamps
    end

    add_index :document_event_logs, [ :document_id, :created_at ]
    add_index :document_event_logs, :event_type
  end
end
