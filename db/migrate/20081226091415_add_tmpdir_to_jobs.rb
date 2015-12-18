class AddTmpdirToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :tmpdir, :string, :after => :state
  end

  def self.down
    remove_column :jobs, :tmpdir
  end
end