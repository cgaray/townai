# frozen_string_literal: true

class AddTownToGoverningBodiesAndPeople < ActiveRecord::Migration[8.1]
  def change
    add_reference :governing_bodies, :town, null: false, foreign_key: true
    add_reference :people, :town, null: false, foreign_key: true
  end
end
