class JobRunner
  
  class << self
    include ::Spawn
    
    def tickle!
      # start the command and return immediately
      spawn(:method => :thread) do
        `#{Rails.root}/bin/exec_task bg:runner log/rake/bg/runner.log 2>&1`
      end
    end
  end
  
end