# Like a check_box, but default checked value is 'true' (instead of '1') and default
# unchecked value is 'false' (instead of '0'). Often the method that you give the
# boolean_check_box points to an attribute in a class defined with boolean_attr_accessor.
#
# Together, these tools let you store a value from a form as a real boolean value
# instead of something like the string "0" or the string "1".
module BooleanCheckBox
  def self.included(klass)
    klass.send(:include, FormTagMethods)
    ActionView::Helpers::InstanceTag.send(:include, BooleanCheckBox::InstanceTagMethods)
    ActionView::Helpers::FormBuilder.send(:include, BooleanCheckBox::FormBuilderMethods)
  end
  def boolean_check_box(object_name, method, options = {}, checked_value = true, unchecked_value = false)
    ActionView::Helpers::InstanceTag.new(object_name, method, self, options.delete(:object)).to_boolean_check_box_tag(options, checked_value, unchecked_value)
  end
  module FormTagMethods
    def boolean_check_box_tag(name, value = true, checked = false, options = {})
      check_box_tag(name, value.to_b, checked, options)
    end
  end
  module InstanceTagMethods
    # I'm not actually sure if we need this or not
    def self.included(klass)
      klass.send(:include, BooleanCheckBox::FormTagMethods)
    end
    def to_boolean_check_box_tag(options = {}, checked_value = true, unchecked_value = false)
      to_check_box_tag(options, checked_value.to_b, unchecked_value.to_b)
    end
  end
  module FormBuilderMethods
    def boolean_check_box(method, options = {}, checked_value = true, unchecked_value = false)
      @template.boolean_check_box(@object_name, method, objectify_options(options), checked_value, unchecked_value)
    end
  end
end

if Object.const_defined?(:ActionView) && ActionView.const_defined?(:Base)
  ActionView::Base.send(:include, BooleanCheckBox)
end