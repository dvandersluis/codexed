class AddStepOffsetToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :step_offset, :float, :after => :tmpdir
  end

  def self.down
    remove_column :jobs, :step_offset
  end
end
