class AddActionTakenRawToTopics < ActiveRecord::Migration[8.1]
  def change
    add_column :topics, :action_taken_raw, :string
  end
end
