module ActiveRecord
  class Base
    def clone_with_attributes(attrs = {})
      copy = self.clone
      copy.attributes = attrs
      copy
    end
  end
end