module ActiveRecord
  class Base
    def self.validates_email(*attr_names)
      options = attr_names.extract_options!
      options[:with] ||= /^[A-Za-z0-9_.%+-]+@([A-Za-z0-9_.-]+)+[A-Za-z]{2,}$/
      attr_names << options
      validates_format_of(*attr_names)
    end
  end
end