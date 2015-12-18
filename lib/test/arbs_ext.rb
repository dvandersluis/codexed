require 'active_support/callbacks'
require 'active_record/callbacks'
require 'active_record/timestamp'
#require File.dirname(__FILE__)+'/validateable'

module ActiveRecord
  # Generic Active Record exception class.
  class ActiveRecordError < StandardError
  end
  # Raised when SQL statement cannot be executed by the database (for example, it's often the case for MySQL when Ruby driver used is too old).
  #class StatementInvalid < ActiveRecordError
  #end

  class Base
    stub_instance_methods :create_or_update, :create, :update, :destroy, :valid?, :save, :save!,
                          :update_attribute, :update_attributes, :update_attributes!
                          
    stub_class_methods :validates_exclusion_of, :validates_acceptance_of, :named_scope,
                       :validates_each
    
    class << self
      def has_one(association_name, options = {})
        attr_accessor association_name
      end
    end
    
    # Our custom extensions
    stub_class_methods :attr_lazy, :remembers_changes_since_last_saved, :validates_presence_of_one_of,
                       :crypted_password, :validates_email
    
    #include ::Validateable
    include ActiveRecord::Callbacks
    include ActiveRecord::Timestamp
  end
end