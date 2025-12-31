class AddStatusIndexToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_index :documents, :status
  end
end
