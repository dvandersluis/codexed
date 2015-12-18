class AddImportJobIdToJournals < ActiveRecord::Migration
  def self.up
    add_column :journals, :import_job_id, :integer, :after => :crypted_entries_password
  end

  def self.down
    remove_column :journals, :import_job_id
  end
end