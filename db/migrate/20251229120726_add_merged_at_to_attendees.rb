class AddMergedAtToAttendees < ActiveRecord::Migration[8.1]
  def change
    add_column :attendees, :merged_at, :datetime
  end
end
