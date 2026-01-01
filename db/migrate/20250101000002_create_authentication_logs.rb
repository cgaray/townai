class CreateAuthenticationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :authentication_logs do |t|
      t.references :user
      t.string :action, null: false
      t.string :email_hash  # SHA256 hash of email for privacy
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    add_index :authentication_logs, [ :user_id, :created_at ]
    add_index :authentication_logs, :action
    add_index :authentication_logs, :email_hash
  end
end
