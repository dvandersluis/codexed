# This setup file was loosely inspired from a post by Jay Fields
# <http://blog.jayfields.com/2007/10/rails-unit-test-without-rails.html>

RAILS_ENV = ENV["RAILS_ENV"] = "test"

$FOCUSED_TEST = true

RAILS_ROOT = File.expand_path(File.dirname(__FILE__) + "/../../../../../")
$PLUGIN_ROOT = File.expand_path(File.dirname(__FILE__) + "/../../")

#$:.unshift(app_root, "#{app_root}/lib")

#load_paths = [ "#{app_root}/vendor/plugins/rspec-rails/lib", "#{app_root}/vendor/plugins/rspec/lib", "#{plugin_root}/test", "#{plugin_root}/lib", "#{app_root}/vendor/plugins" ]
load_paths = [ "#{$PLUGIN_ROOT}/test", "#{$PLUGIN_ROOT}/lib", "#{RAILS_ROOT}/vendor/plugins" ]

# Import Rails' Ruby extensions
require "#{RAILS_ROOT}/vendor/rails/activesupport/lib/active_support"
# Import Rails classes
require "#{RAILS_ROOT}/vendor/rails/activerecord/lib/active_record"
require "#{RAILS_ROOT}/vendor/rails/actionpack/lib/action_controller"
require "#{RAILS_ROOT}/vendor/rails/railties/lib/initializer"

# Initialize Rails
Rails.configuration = config = Rails::Configuration.new
initializer = Rails::Initializer.new(config)
initializer.set_load_path
initializer.set_autoload_paths
initializer.add_plugin_load_paths
initializer.initialize_dependency_mechanism

# Load select plugins
plugin_loader = initializer.plugin_loader
plugins_to_load = %w(rspec rspec-rails)
plugins = plugin_loader.plugins.select {|plugin| plugins_to_load.include?(plugin.name) }
for plugin in plugins
  plugin.load(initializer)
  plugin_loader.send(:register_plugin_as_loaded, plugin)
end

#Dependencies.load_paths = load_paths
#$:.unshift(*load_paths)

#puts "$: = #{$:.inspect}"
#puts "Dependencies.load_paths = #{Dependencies.load_paths.inspect}"

# Connect to the db
db_settings = ActiveRecord::Base.configurations = YAML.load(ERB.new(IO.read("#{$PLUGIN_ROOT}/test/database.yml")).result)
ActiveRecord::Base.logger = Logger.new("#{$PLUGIN_ROOT}/test/debug.log")
ActiveRecord::Base.establish_connection("test")

# Delete and recreate the database
ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS users")
ActiveRecord::Base.connection.execute("
  CREATE TABLE users (
    id integer not null primary key autoincrement,
    username varchar(255) not null,
    crypted_password varchar(255) not null,
    salt varchar(255) not null,
    mnemonic varchar(255)
  )
")

# Load RSpec
require "spec"
require "spec/rails"
Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true
  config.use_instantiated_fixtures  = false
  #config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
end

# Load login_system
require 'login_system'

class User < ActiveRecord::Base
  extend LostInCode::LoginSystem::ClassMethods
  include LostInCode::LoginSystem::InstanceMethods
end