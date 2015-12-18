module ActiveRecord
  class Base
    # RSpec provides this but I just want to make sure it's in here
    def errors_on(attribute)
      [self.errors.on(attribute)].flatten.compact
    end
    alias :error_on :errors_on
  end
  
  class Errors
    attr_reader :errors
  end
end