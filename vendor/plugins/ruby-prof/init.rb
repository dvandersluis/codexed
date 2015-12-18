begin
  require 'ruby-prof'
rescue LoadError
end

if defined?(RubyProf)
  
  require 'profiling'

  # Grab log path from current rails configuration
  ActionController::Profiling.log_path = File.expand_path(File.dirname(config.log_path))
  ActionController::Profiling.level = 0

  ActionController::Base.class_eval do
    include ActionController::Profiling
  end

end