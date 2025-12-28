class CreateApiCalls < ActiveRecord::Migration[8.1]
  def change
    create_table :api_calls do |t|
      t.references :document, null: true, foreign_key: true
      t.string :provider, null: false
      t.string :model, null: false
      t.string :operation, null: false
      t.integer :prompt_tokens
      t.integer :completion_tokens
      t.integer :total_tokens
      t.decimal :cost_credits, precision: 12, scale: 6
      t.integer :response_time_ms
      t.string :status, null: false
      t.text :error_message
      t.timestamps
    end

    add_index :api_calls, :created_at
    add_index :api_calls, :provider
    add_index :api_calls, :model
    add_index :api_calls, :status
  end
end
