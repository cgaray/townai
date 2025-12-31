# frozen_string_literal: true

class ChangeGoverningBodyUniqueIndexToIncludeTown < ActiveRecord::Migration[8.1]
  def change
    # Remove the old unique index on just normalized_name
    remove_index :governing_bodies, :normalized_name

    # Add a new composite unique index on (normalized_name, town_id)
    # This allows the same governing body name in different towns
    add_index :governing_bodies, [ :normalized_name, :town_id ], unique: true
  end
end
