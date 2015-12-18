class MoveUsersJobColumnsToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :journal_id, :integer, :after => :id, :null => false
    Job.reset_column_information
    Journal.find_each(:conditions => "export_job_id IS NOT NULL") do |journal|
      if job = journal.export_job
        job.journal = journal
        job.disabling_validations { job.save! }
        puts "Moved export_job of journal ##{journal.id} to journal_id of job ##{job.id}."
      end
    end
    remove_column :journals, :export_job_id
    Journal.find_each(:conditions => "import_job_id IS NOT NULL") do |journal|
      if job = journal.import_job
        job.journal = journal
        job.disabling_validations { job.save! }
        puts "Moved import_job of journal ##{journal.id} to journal_id of job ##{job.id}."
      end
    end
    remove_column :journals, :import_job_id
  end

  def self.down
    add_column :journals, :import_job_id, :integer
    add_column :journals, :export_job_id, :integer
    remove_column :jobs, :journal_id
  end
end
