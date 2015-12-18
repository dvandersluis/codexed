require File.dirname(__FILE__) + '/../model_test_helper'

require 'erb'

require "#{RAILS_ROOT}/config/boot"

Rails::Initializer.class_eval do
  def alt_process
    Rails.configuration = configuration

    check_ruby_version
    install_gem_spec_stubs
    set_load_path
    
    require_frameworks
    set_autoload_paths
    add_gem_load_paths
    add_plugin_load_paths
    load_environment

    initialize_encoding
    initialize_database

    initialize_cache
    initialize_framework_caches

    initialize_logger
    initialize_framework_logging

    initialize_framework_views
    initialize_dependency_mechanism
    initialize_whiny_nils
    initialize_temporary_session_directory
    initialize_time_zone
    initialize_framework_settings

    add_support_load_paths

    load_gems
    load_plugins

    # pick up any gems that plugins depend on
    add_gem_load_paths
    load_gems
    check_gem_dependencies
    
    ## No thanks, we'll do this manually, thx
    ##load_application_initializers
    Dir["#{RAILS_ROOT}/config/initializers/aaa_extensions/rails/active_record/*.rb"].each {|file| require file }

    # the framework is now fully initialized
    ##after_initialize

    # Prepare dispatcher callbacks and run 'prepare' callbacks
    ##prepare_dispatcher

    # Routing must be initialized after plugins to allow the former to extend the routes
    ##initialize_routing

    # Observers are loaded after plugins in case Observers or observed models are modified by plugins.
    
    ##load_observers
  end
end

Rails::Initializer.run(:alt_process) do |config|
  #config.plugins = Rails::Plugin::FileSystemLocator.new(Rails::Initializer.new(config)).plugins.map {|p| p.name.to_sym }
  #config.plugins -= [ :"12_hour_time" ]
  config.plugins = [ :gloc ]
  
  config.load_paths << "#{Rails.root}/lib/workers"
  config.time_zone = 'UTC'
  config.active_record.schema_format = :sql
  config.active_record.default_timezone = :utc
  config.frameworks = [ :active_record ]
  config.logger = nil
end

#---

require "remarkable"  # loads 'spec-rails'

#---

# Empty each table in the test database manually since I can't seem to figure out
# how to do this otherwise
tables = ActiveRecord::Base.connection.select_values("SHOW TABLES")
for table in (tables - ["schema_migrations"])
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE `#{table}`")
end

Spec::Runner.configure do |config|
  config.use_transactional_fixtures = true   # this should work but doesn't for whatever reason
  config.use_instantiated_fixtures  = false
  #config.fixture_path = RAILS_ROOT + '/spec/fixtures/'
  
  #config.mock_with :mocha
  
  # Codexed stuff
  #config.before(:each) { Codexed.autocreate_config_dirs }
  #config.after(:each)  { Codexed.remove_config_dirs     }
end

#---

require "config/initializers/gloc"

GLoc.set_language("en")