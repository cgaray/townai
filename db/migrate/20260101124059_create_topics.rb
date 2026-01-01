class CreateTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :topics do |t|
      # index: false because composite index on [document_id, position] covers document_id queries
      t.references :document, null: false, foreign_key: true, index: false
      t.string :title, null: false
      t.text :summary
      t.integer :action_taken, default: 0
      t.text :source_text
      t.integer :position, default: 0

      # Future extension fields (nullable)
      t.string :category
      t.integer :amount_cents
      t.string :amount_type

      t.timestamps
    end

    add_index :topics, %i[document_id position]
    add_index :topics, :action_taken
    add_index :topics, :category
  end
end
