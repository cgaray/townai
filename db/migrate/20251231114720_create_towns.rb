# frozen_string_literal: true

class CreateTowns < ActiveRecord::Migration[8.1]
  def change
    create_table :towns do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :slug, null: false

      t.timestamps
    end

    add_index :towns, :normalized_name, unique: true
    add_index :towns, :slug, unique: true
  end
end
