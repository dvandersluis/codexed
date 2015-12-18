# TODO: Merge this with the boolean_attr_* methods
module ActiveRecord
  class Base
    def self.attr_boolean(*attrs)
      for attr in attrs
        class_eval(<<-EOT, __FILE__, __LINE__)
          def #{attr}?; @#{attr}; end
          def #{attr}=(value); @#{attr} = value; end
          def #{attr}!; @#{attr} = true; end
        EOT
      end
    end
  end
end