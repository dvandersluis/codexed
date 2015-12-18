### UGH THIS IS UNFINISHED

module ActiveRecord
  # Generic Active Record exception class.
  class ActiveRecordError < StandardError
  end
  # Raised when SQL statement cannot be executed by the database (for example, it's often the case for MySQL when Ruby driver used is too old).
  class StatementInvalid < ActiveRecordError
  end
end

require 'active_record/validations'

# Based on Chad Fowler's Validateable module in Rails Recipes
# Fixed for Rails 1.2 by Bill Burcham <http://meme-rocket.com/2007/01/07/updated-validateable-recipe/>
# Does this work for Rails 2.0?
module Validateable
  def self.included(base)
    base.send(:include, ActiveRecord::Validations)
    base.extend(ClassMethods)
  end
  for method in [:save, :save!, :update_attribute]
    define_method(method) {}
  end
  def method_missing(symbol, *params)
    if(symbol.to_s =~ /(.*)_before_type_cast$/)
      send($1)
    end
  end
  module ClassMethods
    for method in [:column_names]
      define_method(method) {}
    end
    def human_attribute_name(attribute_key_name)
      attribute_key_name.humanize
    end
  end
end