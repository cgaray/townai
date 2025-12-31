# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      ## Email (required for magic link authentication)
      t.string :email, null: false, default: ""

      ## Admin flag
      t.boolean :admin, null: false, default: false

      ## Rememberable
      t.datetime :remember_created_at

      t.timestamps null: false
    end

    add_index :users, :email, unique: true
  end
end
