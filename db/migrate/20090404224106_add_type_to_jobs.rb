class AddTypeToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :type, :string, :null => false, :after => :id
  end

  def self.down
    remove_column :jobs, :type
  end
end
