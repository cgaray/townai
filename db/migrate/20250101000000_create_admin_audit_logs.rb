class CreateAdminAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.string :resource_type, null: false
      t.bigint :resource_id
      t.text :params
      t.text :previous_state
      t.text :new_state
      t.string :ip_address
      t.timestamps
    end

    add_index :admin_audit_logs, [ :user_id, :created_at ]
    add_index :admin_audit_logs, [ :resource_type, :resource_id ]
    add_index :admin_audit_logs, :action
  end
end
