module Factory
  def self.included(klass)
    klass.extend(ClassMethods)
  end
  module ClassMethods
    def factory(name, defaults = {})
      factory_defaults[name.to_s] = defaults
      class_eval(<<-EOT, __FILE__, __LINE__)
      private
        def #{name}_defaults
          self.class.factory_defaults['#{name}']
        end
        def new_#{name}(attributes = {})
          #{name.to_s.classify}.new(#{name}_defaults.merge(attributes))
        end
        def create_#{name}!(attributes = {})
          returning(new_#{name}(attributes)) {|record| record.save! }
        end
      EOT
    end
    def factory_defaults
      @factory_defaults ||= {}
    end
  end
end
