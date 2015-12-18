class AddExportJobIdToJournals < ActiveRecord::Migration
  def self.up
    add_column :journals, :export_job_id, :integer, :after => :crypted_entries_password
  end

  def self.down
    remove_column :journals, :export_job_id
  end
end
