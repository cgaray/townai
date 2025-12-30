class DropDocumentSections < ActiveRecord::Migration[8.1]
  def up
    drop_table :document_sections
  end

  def down
    create_table :document_sections do |t|
      t.references :document, null: false, foreign_key: true
      t.string :title, null: false
      t.string :section_type, null: false
      t.integer :page_start, null: false
      t.integer :page_end, null: false
      t.integer :position, null: false, default: 0
      t.timestamps
    end

    add_index :document_sections, [ :document_id, :position ]
    add_index :document_sections, :section_type
  end
end
