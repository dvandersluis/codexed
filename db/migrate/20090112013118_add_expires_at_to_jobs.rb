class AddExpiresAtToJobs < ActiveRecord::Migration
  def self.up
    add_column :jobs, :expires_at, :datetime, :after => :finished_at
    
    # ensure expires_at is set for all jobs
    Job.all.each {|job| job.save! }
  end

  def self.down
    remove_column :jobs, :expires_at
  end
end
