# This setup file was loosely inspired from a post by Jay Fields
# <http://blog.jayfields.com/2007/10/rails-unit-test-without-rails.html>

RAILS_ENV = ENV["RAILS_ENV"] = "test"

$FOCUSED_TEST = true

app_root = File.expand_path(File.dirname(__FILE__) + "/../../../../../")
plugin_root = File.expand_path(File.dirname(__FILE__) + "/../../")

$:.unshift(app_root, "#{app_root}/lib")

load_paths = [ "#{plugin_root}/test", "#{plugin_root}/lib", "#{app_root}/vendor/plugins" ]

# Import Rails' Ruby extensions
require "vendor/rails/activesupport/lib/active_support"

# Load Rails
=begin
require "#{RAILS_ROOT}/vendor/rails/railties/lib/initializer"
Rails.configuration = config = Rails::Configuration.new
gems_to_load = %w(mocha expectations)
for dir in Dir["#{RAILS_ROOT}/vendor/gems/**"]
  next unless gems_to_load.any? {|gem_name| File.basename(dir).starts_with?(gem_name) }
  config.load_paths << (File.directory?(lib = "#{dir}/lib") ? lib : dir)
end
initializer = Rails::Initializer.new(config)
initializer.set_load_path
initializer.set_autoload_paths
initializer.add_plugin_load_paths
initializer.initialize_dependency_mechanism
=end

Dependencies.load_paths = load_paths
$:.unshift(*load_paths)

# Load arbs
require "test/arbs/arbs"

# Set up logging
logger = ActiveSupport::BufferedLogger.new(STDERR)
logger.level = ActiveSupport::BufferedLogger::WARN
ActiveRecord::Base.logger = logger

# Load expectations
require 'vendor/gems/expectations-1.0.0/lib/expectations'

# Load validatable
require 'vendor/gems/validatable-1.6.7/lib/validatable'

# Load login_system
require 'login_system'

class User < ActiveRecord::Base
  extend LostInCode::LoginSystem::ClassMethods
  include LostInCode::LoginSystem::InstanceMethods
end

ArbsGenerator.run("#{plugin_root}/test/schema.rb")