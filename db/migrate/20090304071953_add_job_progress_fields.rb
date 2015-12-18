class AddJobProgressFields < ActiveRecord::Migration
  def self.up
    add_column :jobs, :goal, :integer, :after => :progress
    add_column :jobs, :activity, :string, :after => :goal
    add_column :jobs, :subprogress, :integer, :after => :activity
    add_column :jobs, :subgoal, :integer, :after => :subprogress
    add_column :jobs, :subactivity, :string, :after => :subgoal
  end

  def self.down
    remove_column :jobs, :subactivity
    remove_column :jobs, :activity
    remove_column :jobs, :subgoal
    remove_column :jobs, :subprogress
    remove_column :jobs, :goal
  end
end
