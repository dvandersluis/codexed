# Be sure to restart your server when you modify this file

# Uncomment below to force Rails into production mode when
# you don't control web/app server and can't set it the proper way
ENV['RAILS_ENV'] ||= 'production'

# Specifies gem version of Rails to use when vendor/rails is not present
#RAILS_GEM_VERSION = '2.3.2' unless defined? RAILS_GEM_VERSION

# Bootstrap the RAILS environment, frameworks, and default configuration
require File.join(File.dirname(__FILE__), 'boot')

if RAILS_ENV == 'production'
  require 'logging'
  Logging.init :debug, :info, :warn, :error, :fatal
  layout = Logging::Layouts::Pattern.new :pattern => "[%d] [%-5l] %m\n" 
  rolling_appender = Logging::Appenders::RollingFile.new('production',
    :filename => "log/codexed.log",
    :safe => true,
    :age => 'daily',
    :keep => 0,
    :layout => layout
  )
  stdout_appender = Logging::Appenders::Stdout.new(
    :layout => layout
  )
end

Rails::Initializer.run do |config|
  config.load_paths << "#{Rails.root}/lib/workers"
  config.load_paths << "#{Rails.root}/app/sweepers"
  
  config.action_controller.page_cache_directory = RAILS_ROOT + "/public/cache"
  config.active_record.observers = :post_sweeper, :template_sweeper, :journal_sweeper
  
  config.i18n.default_locale = :en
  
  # Save a little memory by not loading ActiveResource, since we never use it
  config.frameworks -= [ :active_resource ]

  # Set up gem dependencies
  config.gem "andand", :version => "1.3.1"
  config.gem "chardet", :version => "0.9.0", :lib => "UniversalDetector"
  config.gem "colorist", :version => "0.0.2"
  config.gem "expectations", :version => "1.2.0"
  config.gem "haml", :version => "2.0.9"
  config.gem "lockfile", :version => "1.4.3"
  config.gem "logging", :version => "0.9.6"
  config.gem "maruku", :version => "0.5.8"
  config.gem "mislav-will_paginate", :version => "2.3.8", :lib => "will_paginate"
  config.gem "RedCloth", :version => "4.1.1", :lib => "redcloth"
  config.gem "rubyzip", :version => "0.9.1", :lib => "zip/zip"
  #config.gem "ruby-prof", :version => "0.7.3"
  config.gem "unidecode", :version => "1.0.0"

  # Only load the plugins named here, in the order given. By default, all plugins 
  # in vendor/plugins are loaded in alphabetical order.
  # :all can be used as a placeholder for all plugins not explicitly named
  config.plugins = Rails::Plugin::FileSystemLocator.new(Rails::Initializer.new(config)).plugins.map {|p| p.name.to_sym }
  if RAILS_ENV == "profiling"
    config.plugins -= [ :query_trace ]
  end

  # Force all environments to use the same logger level
  # (by default production uses :info, the others :debug)
  #config.log_level = :debug
  
  # Make Time.zone default to the specified zone, and make ActiveRecord store time values
  # in the database in UTC, and return them converted to the specified local zone.
  # Run `rake -D time` for a list of tasks for finding time zone names. Uncomment to use default local time.
  config.time_zone = 'UTC'

  # Your secret key for verifying cookie session data integrity.
  # If you change this key, all old sessions will become invalid!
  # Make sure the secret is at least 30 characters and all random, 
  # no regular words or you'll be exposed to dictionary attacks.
  config.action_controller.session = {
    :key     => '_codexed_session',
    :secret  => 'aabaf62bb57d384ac01466df5467351e4862eac0a08493ddab8be75cb2eb80076bc3f7d44f54c5e481c03abeed3c1a4e688d2d347424f29e9b6e0bffed98437d',
    :domain  => '.codexed.com'
  }

  # Use the database for sessions instead of the cookie-based default,
  # which shouldn't be used to store highly confidential information
  # (create the session table with 'rake db:sessions:create')
  config.action_controller.session_store = :active_record_store

  # Use SQL instead of Active Record's schema dumper when creating the test database.
  # This is necessary if your schema can't be completely dumped by the schema dumper,
  # like if you have constraints or database-specific column types
  config.active_record.schema_format = :sql

  # Activate observers that should always be running
  # config.active_record.observers = :cacher, :garbage_collector

  # Make Active Record use UTC-base instead of local time
  config.active_record.default_timezone = :utc
  
  # Set up the log files so they auto-rotate daily
  if RAILS_ENV == 'production'
    logger = Logging::Logger.new(RAILS_ENV)
    logger.add_appenders(rolling_appender)
    logger.add_appenders(stdout_appender)
    logger.level = :info
    config.logger = logger
  else
    #config.logger = ActiveSupport::BufferedLogger.new("#{RAILS_ROOT}/log/#{RAILS_ENV}.log", 'debug')
  end
  
  #config.active_record.allow_concurrency = true
end

#============================================

# Require misc files here
# If it gets too complicated, move to initializers/

if defined?(ActionController::Profiling)
  # Set this to greater than 0 to profile every controller action
  # 1 will print a brief report to the log
  # 2 will generate a call graph in the log folder
  ActionController::Profiling.level = 0
end
