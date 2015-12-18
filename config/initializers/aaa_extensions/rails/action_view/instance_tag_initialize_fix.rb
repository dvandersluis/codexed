if Object.const_defined?(:ActionView) && ActionView.const_defined?(:Base)
  class ActionView::Helpers::InstanceTag
    def initialize(object_name, method_name, template_object, object = nil)
      @object_name, @method_name = object_name.to_s.dup, method_name.to_s.dup
      @template_object = template_object
      @object = object
      # don't extract the [] at the end unless the part before is actually an instance variable
       if @object_name =~ /\[\]$/
        ivar = "@#{Regexp.last_match.pre_match}"
        # check for the existence of the instance variable before getting it
        # this fixes the case where the object_name just acts as a prefix to the name of each form element created
        #  using the FormBuilder
        if @template_object.instance_variables.include?(ivar)
          if @object_name.sub!(/\[\]$/,"") || @object_name.sub!(/\[\]\]$/,"]")
            if object ||= @template_object.instance_variable_get(ivar) and object.respond_to?(:to_param)
              @auto_index = object.to_param
            else
              raise ArgumentError, "object[] naming but object param and @object var don't exist or don't respond to to_param: #{object.inspect}"
            end
          end
        end
      end
    end
  end
end