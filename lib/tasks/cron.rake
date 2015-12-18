namespace :cron do
  desc "Sends activation emails to newly registered users."
  task :send_activation_emails => :environment do
    User.find_deactivated.each do |user|
      Mailer.deliver_activation_email(user)
    end
  end

  desc "Deletes rows from the sessions table that are at least five days old."
  task :delete_old_sessions => :environment do
    num_sessions = Session.delete_all(["updated_at < ?", 5.days.ago])
    puts "#{num_sessions} old session(s) deleted."
  end
  
  desc "Deletes import/export jobs that are a day old or older, along with their temp directories."
  task :delete_old_jobs => :environment do
    # employ Job's after_destroy callback to delete the directory that holds each job's data
    # note that this returns a collection of records unlike delete_all
    jobs = Job.destroy_all(["expires_at <= ?", Time.now.utc])
    puts "#{jobs.length} old job(s) deleted."
  end
end
