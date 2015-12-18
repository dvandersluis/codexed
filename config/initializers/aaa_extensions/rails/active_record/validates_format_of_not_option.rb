# Add a :not option to validates_format_of
module ActiveRecord
  class Base
    def self.validates_format_of(*attr_names)
      configuration = { :on => :save }
      configuration.update(attr_names.extract_options!)

      unless configuration.include?(:with) ^ configuration.include?(:not)  # ^ == xor, or "exclusive or"
        raise ArgumentError, "Either :with or :not must be supplied (but not both)"
      end
      if configuration[:with] and !configuration[:with].is_a?(Regexp)
        raise(ArgumentError, "A regular expression must be supplied as the :with option of the configuration hash") 
      end
      if configuration[:not] and !configuration[:not].is_a?(Regexp)
        raise(ArgumentError, "A regular expression must be supplied as the :not option of the configuration hash") 
      end

      validates_each(attr_names, configuration) do |record, attr_name, value|
        if configuration[:with] && value.to_s !~ configuration[:with]
          record.errors.add(attr_name, configuration[:message]) 
        end
        if configuration[:not] && value.to_s =~ configuration[:not]
          record.errors.add(attr_name, configuration[:message])
        end
      end
    end
  end
end
