class AddReviewFieldsToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :extraction_confidence, :string
    add_column :documents, :reviewed_at, :datetime
    add_reference :documents, :reviewed_by, null: true, foreign_key: { to_table: :users }
    add_column :documents, :rejection_reason, :text

    add_index :documents, :extraction_confidence
    add_index :documents, :reviewed_at
  end
end
