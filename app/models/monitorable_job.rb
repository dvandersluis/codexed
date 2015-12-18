class MonitorableJob < UnmonitorableJob
  
  self.states += %w(stopping stopped)
  define_state_methods
  
  class << self
    # Overrides method in Job
    def worker_base_class
      MonitorableJobWorker
    end
  end
  
  # Overrides method in Job
  def restart!
    unless running? || stopping?
      update_attributes!(
        :state => "pending",
        :result => nil, 
        :exception_class => nil,
        :exception_backtrace => nil,
        :goal => nil,
        :activity => nil,
        :progress => nil,
        :subgoal => nil,
        :subactivity => nil,
        :subactivity_params => nil,
        :subprogress => nil,
        :started_at => nil,
        :last_updated_progress_at => nil
      ) 
      logger.warn("Background Job: Restarting job #{id}.")
      self.class.tickle_runner
    else
      logger.warn("Background Job: Can't restart job #{id}, it's still running!")
    end
  end
  
  # Overrides method in Job
  def resume_at!(method)
    unless running?
      update_attributes!(
        :worker_method => method.to_s,
        :state => "pending",
        :result => nil, 
        :exception_class => nil,
        :exception_backtrace => nil,
        :goal => nil,
        :activity => nil,
        :progress => nil,
        :subgoal => nil,
        :subactivity => nil,
        :subactivity_params => nil,
        :subprogress => nil,
        :last_updated_progress_at => nil
      ) 
      logger.warn("Background Job: Resuming #{id} at #{method}.")
      self.class.tickle_runner
    else
      logger.warn("Background Job: Can't resume job #{id}, it's already running!")
    end
  end
  
  # Allows you to kill a job which has been set up to be monitored. What this means
  # is that the worker class must be inherited from MonitorableJobWorker, and must
  # call record_progress() within it. Every time the worker invokes record_progress()
  # is a possible stopping place.
  #
  # How it works:
  # 1. Invoking job.stop! sets the job's state in the db to "stopping".
  # 2. The monitoring thread picks up the state change from db and sets @stopping
  #    to true in the worker.
  # 3. The worker invokes record_progress() somewhere during execution.
  # 4. The record_progress() method throws a :stopping symbol
  # 5. The job catches the :stopping symbol and does whatever is necessary to end the job.
  #---
  # TODO Add support back for this in the MonitorableJobWorker
  def stop!
    if running?
      update_attributes!(:state => "stopping")
      logger.warn("Background Job: Stopping job #{id}")
    end
  end
  
  # Returns a decimal number that represents the shallow progress of this job (0 to 1).
  def progress_decimal
    progress / goal.to_f if progress && goal.to_i > 0
  end
  # Returns the total progress of this job, in percentage form (0 to 100).
  def progress_percentage
    progress_decimal ? progress_decimal * 100 : 0.0
  end
  # Returns a decimal number that represents the progress within the current step (0 to 1).
  def subprogress_decimal
    subprogress / subgoal.to_f if subprogress && subgoal.to_i > 0
  end
  # Returns the progress within the current step, in percentage form (0 to 100).
  def subprogress_percentage
    subprogress_decimal ? subprogress_decimal * 100 : 0.0
  end
  # Returns a decimal number that represents the the overall progress of this job (0 to 1).
  def overall_progress_decimal
    p, sp = progress_decimal, subprogress_decimal
    return unless p
    sp ? p + (sp / goal.to_f) : p
  end
  # Returns the overall progress, in percentage form (0 to 100).
  def overall_progress_percentage
    overall_progress_decimal ? overall_progress_decimal * 100.0 : 0.0
  end
  
  # Returns how long (in seconds) the job has been running for.
  def elapsed_time
    updated_at.to_f - started_at.to_f if running?
  end
    
  # Returns an estimate of how many seconds are left until the job finishes.
  # If a subprogress bar is being shown, then we estimate the time it will take to finish
  #  the current step and use that to determine the total remaining time
  # Otherwise, we estimate the time it will take to finish the whole job and use that
  def estimated_time
    return unless running? && (progress.to_i > 0 || subprogress.to_i > 0) && goal.to_i > 0

    time_remaining = nil
    
    if subprogress_decimal
      elapsed_time_in_this_step = Time.now.to_f - (last_updated_progress_at || started_at).to_f
      time_per_subprogress = subprogress_percentage.infinite? ? 0 : elapsed_time_in_this_step / subprogress_percentage 
      estimated_time_in_this_step = time_per_subprogress * 100
      num_steps_remaining = goal - progress
      num_steps_remaining += step_offset if step_offset
      time_remaining = (estimated_time_in_this_step * num_steps_remaining) - elapsed_time_in_this_step
    else
      time_per_progress = overall_progress_percentage.infinite? ? 0 : elapsed_time / overall_progress_percentage
      overall_progress_remaining = (100.0 - overall_progress_percentage)
      elapsed_time_in_this_step = Time.now.to_f - (last_updated_progress_at || started_at).to_f
      time_remaining = (time_per_progress * overall_progress_remaining) - elapsed_time_in_this_step
    end
    
    #time_remaining = nil if time_remaining.infinite? or time_remaining.nan?
    
    time_remaining
  end
  
private
  # Executes the job by creating a new instance of the worker class and calling the
  # method on the worker. You should never have to call this manually; this is invoked
  # by the job runner.
  def get_done!
    super
  ensure
    ensure_worker
  end
  
  def invoke_worker
    monitor_worker    
    caught_stopping = catch(:stopping) do
      super
    end    
    #reload   # XXX: won't this clear the changes?!?
    self.state = "stopped" if caught_stopping
  end
  
  def ensure_worker
    load_data_from_worker
    clean_up_monitoring
  rescue ActiveRecord::StaleObjectError
    # Ignore this exception as its only purpose is
    # to disallow multiple daemons to execute the same job.
  end
  
  # Monitors the worker in a separate thread, updating the job progress in the
  # database every so often. If the job's status is changed to 'stopping' via #stop!,
  # the worker is requested to stop.
  def monitor_worker
    @monitor_thread = spawn(:method => :thread) do
      load_data_from_worker && sleep(1) while running? && !Job.find(id).stopping?
      logger.info "Background Job: Finished monitoring (state is: #{state})"
      @worker.stopping = true if Job.find(id).stopping?
    end
    logger.warn("Background Job: Job monitoring started for job #{id}.")
  end
  
  def load_data_from_worker
    %w(progress goal subprogress subgoal activity subactivity subactivity_params last_updated_progress_at step_offset).each do |attr|
      self.send "#{attr}=", @worker.send(attr)
    end
    save!
  end
  
  # Waits for the monitoring thread to finish if hasn't already, and makes sure that
  # any database connection the thread created is gone.
  def clean_up_monitoring
    logger.warn("Background Job: Monitor thread hasn't finished yet! Let's wait a little and then kill it.")
    sleep 3
    Thread.kill(@monitor_thread.handle)
    logger.warn("Background Job: Monitor thread killed.")
    logger.warn
    ActiveRecord::Base.verify_active_connections!
  end
  
end
