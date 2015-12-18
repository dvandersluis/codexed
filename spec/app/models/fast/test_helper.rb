require File.dirname(__FILE__)+'/../model_test_helper'

require 'arbs'

#---

# Arbs extensions

require 'active_support/callbacks'
require 'active_record/callbacks'
require 'active_record/timestamp'
#require File.dirname(__FILE__)+'/validateable'

module ActiveRecord
  # Generic Active Record exception class.
  class ActiveRecordError < StandardError
  end
  
  class Base
    stub_instance_methods :create_or_update, :create, :update, :destroy

    stub_class_methods :validates_exclusion_of, :validates_acceptance_of, :validates_each, :find, :table_name
    
    def id
      object_id
    end
    
    def save
      true
    end
    alias_method :save!, :save
    
    def valid?
      true
    end
    
    def update_attribute(name, value)
      send("#{name}=", value)
    end
    
    def update_attributes(attrs)
      attrs.each {|k,v| send("#{k}=", v) }
    end
    alias_method :update_attributes!, :update_attributes
                       
    class << self
      def belongs_to(association_name, options = {})
        attr_accessor association_name
      end

      def has_one(association_name, options = {})
        attr_accessor association_name
      end

      def has_many(association_name, options = {})
        attr_writer association_name
        define_method association_name do
          read_attribute(association_name) || write_attribute(association_name, [])
        end
      end
      alias has_and_belongs_to_many has_many
      
      def named_scope(name, options = {})
        (class << self; self; end).class_eval do
          define_method(name) { Scope.new }
        end
      end
      
      def column_names
        []
      end
      
      def transaction
        yield
      end
      
      def create(attrs = {})
        new(attrs)
      end
      alias_method :create!, :create
    end
    
    class Scope
      def conditions
        ""
      end
    end
  
    #include ::Validateable
    include ActiveRecord::Callbacks
    include ActiveRecord::Timestamp
  end
end

#---

# Stub methods not part of ActiveRecord (mostly just our stuff)
ActiveRecord::Base.class_eval do
  stub_class_methods :validates_email, :add_without, :add_bypass_for, :acts_as_tree, :participates_in_login_system,
                     :boolean_attr_accessor, :attr_lazy, :remembers_changes_since_last_saved,
                     :after_timestamps_on_create, :attr_readonly, :l, :validates_presence_of_one_of, :crypted_password,
                     :attr_boolean
  class << self
    alias_method :boolean_named_scope, :named_scope
  end
end

# Set up logging (not sure if this is necessary)
#logger = ActiveSupport::BufferedLogger.new(STDERR)
#logger.level = ActiveSupport::BufferedLogger::WARN
#ActiveRecord::Base.logger = logger

#Dir["#{RAILS_ROOT}/app/models/*.rb"].each {|file| require file }
ArbsGenerator.run(RAILS_ROOT + "/db/schema.rb")