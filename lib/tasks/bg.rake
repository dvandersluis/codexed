namespace :bg do
  task :init do
    $stdout.sync = true
    puts
    puts "--------------------"
    Rake::Task['environment'].invoke
    $trace = Rake.application.options.trace = true
  end
  
  desc "Executes the pending jobs in the background job queue"
  task :runner => :init do
    puts ">>> Job runner started at #{Time.now}."
    
    while job = Job.pending.ordered_by("created_at").first
      puts "Found job ##{job.id}, executing..."
      job.send :get_done!
      if job.failed?
        puts "  failed!"
      elsif job.paused?
        puts "  paused."
      else
        puts "  finished!"
      end
    end
    
    puts ">>> Job runner ended at #{Time.now}."
    puts "--------------------"
    puts
  end
end