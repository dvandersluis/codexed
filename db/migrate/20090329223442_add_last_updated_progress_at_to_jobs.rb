class AddLastUpdatedProgressAtToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :last_updated_progress_at, :datetime
  end

  def self.down
    remove_column :jobs, :last_updated_progress_at
  end
end
