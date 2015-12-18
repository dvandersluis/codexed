class AddSubactivityParamsToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :subactivity_params, :string, :limit => 1024, :default => nil, :null => true, :after => :subactivity
  end

  def self.down
    remove_column :jobs, :subactivity_params
  end
end
