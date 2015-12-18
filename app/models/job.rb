require 'yaml/store'

# Adapted from BackgroundFu
class Job < ActiveRecord::Base

  class << self
    # Sets up the job with the specified worker class and a method of that class
    # which will be called when the job is run, then autostarts the job runner if it
    # isn't running yet.
    #
    # If your job uses a directory to store data, you can specify the path using the
    # :tmpdir option. The directory will be autocreated if it doesn't exist.
    #
    # If you pass a block, it will be called right after the temp directory is created
    # and right before the Job record is created. This allows you to add a file to
    # the temp directory, or whatever you need.
    def enqueue!(worker_class, worker_method, args=[], options={}, &block)
      raise "Given worker class is not a subclass of #{worker_base_class}!" unless worker_class < worker_base_class
      
      tmpdir = options[:tmpdir]
      
      if tmpdir
        FileUtils.rm_rf(tmpdir)
        FileUtils.mkdir(tmpdir)
      end
      block.call if block
      
      job = create!(
        :worker_class  => worker_class.to_s,
        :worker_method => worker_method.to_s,
        :args          => args,
        :tmpdir        => tmpdir
      )
      
      tickle_runner
    
      job
    rescue Exception => e
      if job
        job.rescue_worker(e)
        job.save!
      end
    end
    
    # Autostarts the job runner if it hasn't been started yet.
    def tickle_runner
      logger.warn("Background Job: Tickling the job runner.")
      JobRunner.tickle!
    end
    
    def define_state_methods
      states.each do |state_name|
        define_method("#{state_name}?") { state == state_name }
        named_scope(state_name, :conditions => { :state => state_name })
      end
    end
    
    def worker_base_class
      JobWorker
    end
  end

  cattr_accessor :states
  self.states = %w(pending running paused finished failed)
  define_state_methods

  serialize :args, Array
  serialize :result
  serialize :exception_backtrace, Array
  
  attr_readonly :worker_class, :args, :tmpdir
  
  #---
  
  belongs_to :journal
  
  validates_presence_of :worker_class, :worker_method
  
  before_create :setup_state
  before_update :update_expires_at
  after_destroy :remove_tmpdir
  
  #---
  
  # Executes the job by creating a new instance of the worker class and calling the
  # method on the worker. You should never have to call this manually; this is invoked
  # by the job runner.
  def get_done!
    initialize_worker
    invoke_worker
  rescue Exception => e
    rescue_worker(e)
    save!
  end
  
  def rescue_worker(exception)
    self.attributes = {
      :exception_class => exception.class.to_s,
      :exception_message => exception.message,
      :exception_backtrace => exception.backtrace,
      :state => "failed"
    }
    logger.warn("Background Job: Job #{id} failed with message: #{exception.message}, backtrace is below:")
    logger.warn(exception.backtrace.join("\n"))
  end
  
  # Restarts the job, if it's not running.
  # Be aware that you must ensure that the +tmpdir+ is deleted before you call this,
  #  if your worker uses a temp directory.
  def restart!
    unless running?
      update_attributes!(
        :state => "pending",
        :result => nil, 
        :exception_class => nil,
        :exception_backtrace => nil,
        :started_at => nil
      ) 
      logger.warn("Background Job: Restarting job #{id}.")
      self.class.tickle_runner
    else
      logger.warn("Background Job: Can't restart job #{id}, it's still running!")
    end
  end
  
  # Like restarting the job, except allows you to pick a different worker method.
  def resume_at!(method)
    unless running?
      update_attributes!(
        :worker_method => method.to_s,
        :state => "pending",
        :result => nil, 
        :exception_class => nil,
        :exception_backtrace => nil
      ) 
      logger.warn("Background Job: Resuming #{id} at #{method}.")
      self.class.tickle_runner
    else
      logger.warn("Background Job: Can't resume job #{id}, it's already running!")
    end
  end
  
  # Returns the number of jobs which in are the job queue ahead of this one.
  def jobs_ahead
    self.class.scoped(
      :conditions => ['jobs.created_at < ? and (jobs.state = "pending" or jobs.state = "running")', created_at]
    )
  end

private
  def initialize_worker
    self.started_at ||= Time.now
    self.state = "running"
    @worker = worker_class.constantize.new(self)
  end
  
  def invoke_worker
    ret = @worker.send(worker_method, *args)
    if ret == :paused
      self.state = "paused"
    else
      self.state = "finished"
      self.finished_at = Time.now
    end
    self.result = nil  # or should this actually store something?
    nil
  end

  # called before create
  def setup_state
    self.state = "pending"
  end
  
  # called before update
  def update_expires_at
    return unless updated_at
    # localtime returns the value of updated_at here (which is in the user's time zone)
    # converted to the server time zone
    self.expires_at = (updated_at.localtime + 2.days).at_beginning_of_day
  end
  
  # called after destroy
  def remove_tmpdir
    FileUtils.rm_rf(self.tmpdir) if tmpdir
  end

end  
