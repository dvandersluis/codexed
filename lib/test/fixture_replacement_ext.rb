module FixtureReplacementController
  class MethodGenerator
    
    alias_method :orig_generate_methods, :generate_methods
    def generate_methods
      orig_generate_methods
      generate_new_without_method
      generate_create_without_method
    end
    
    def generate_new_without_method
      obj = @object_attributes
      ClassFactory.fixture_replacement_module.module_eval do
        define_method("new_#{obj.fixture_name}_without") do |*exceptions|
          attributes = exceptions.extract_options!
          obj.to_new_class_instance(attributes, self, exceptions)
        end
      end
    end
    
    def generate_create_without_method
      obj = @object_attributes
      ClassFactory.fixture_replacement_module.module_eval do
        define_method("create_#{obj.fixture_name}_without") do |*exceptions|
          attributes = exceptions.extract_options!
          obj.to_created_class_instance(attributes, self, exceptions)
        end
      end
    end
  end
  
  class AttributeCollection
    def to_new_class_instance(hash={}, caller=self, exceptions=[])
      ClassFactory.active_record_factory.new(self, hash, caller).to_new_instance(exceptions)
    end
    
    def to_created_class_instance(hash={}, caller=self, exceptions=[])
      ClassFactory.active_record_factory.new(self, hash, caller).to_created_instance(exceptions)
    end
  end
  
  class ActiveRecordFactory
    def to_new_instance(exceptions=[])
      @exceptions = exceptions
      new_object = @attributes.active_record_class.new
      assign_values_to_instance new_object
      return new_object
    end
    
    def to_created_instance(exceptions=[])
      created_obj = self.to_new_instance(exceptions)
      created_obj.save!
      return created_obj
    end
    
    def all_attributes
      @attributes.merge!
      @all_merged_attributes ||= attributes_hash.merge(self.hash_given_to_constructor).except(*@exceptions)
    end
  end
end

