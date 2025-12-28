class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :source_file_name
      t.string :source_file_hash
      t.text :raw_text
      t.integer :status, default: 0
      t.text :extracted_metadata
      t.timestamps
    end

    add_index :documents, :source_file_hash, unique: true
  end
end
