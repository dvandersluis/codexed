RAILS_ROOT = File.expand_path(File.dirname(__FILE__)+'/../../../')
$LOAD_PATH.unshift RAILS_ROOT, "#{RAILS_ROOT}/lib", "#{RAILS_ROOT}/lib/papyrus"

RAILS_ENV = 'test'

require '_support'
require 'papyrus'

#require 'config/initializers/ruby-prof'
#ActionController::Profiling.log_path = File.dirname(__FILE__)