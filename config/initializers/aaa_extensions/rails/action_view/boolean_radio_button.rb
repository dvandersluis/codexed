# Like a radio_button, but default checked value is 'true' (instead of '1') and default
# unchecked value is 'false' (instead of '0'). Often the method that you give the
# boolean_radio_button points to an attribute in a class defined with boolean_attr_accessor.
#
# Together, these tools let you store a value from a form as a real boolean value
# instead of something like the string "0" or the string "1".
module BooleanRadioButton
  def self.included(klass)
    klass.send(:include, FormTagMethods)
    ActionView::Helpers::InstanceTag.send(:include, BooleanRadioButton::InstanceTagMethods)
    ActionView::Helpers::FormBuilder.send(:include, BooleanRadioButton::FormBuilderMethods)
  end
  def boolean_radio_button(object_name, method, tag_value, options = {})
    ActionView::Helpers::InstanceTag.new(object_name, method, self, options.delete(:object)).to_boolean_radio_button_tag(tag_value, options)
  end
  module FormTagMethods
    def boolean_radio_button_tag(name, tag_value, checked = false, options = {})
      radio_button_tag(name, tag_value.to_b, checked, options)
    end
  end
  module InstanceTagMethods
    # I'm not actually sure if we need this or not
    def self.included(klass)
      klass.send(:include, BooleanRadioButton::FormTagMethods)
    end
    def to_boolean_radio_button_tag(tag_value, options = {})
      to_radio_button_tag(tag_value.to_b, options)
    end
  end
  module FormBuilderMethods
    def boolean_radio_button(method, tag_value, options = {})
      @template.boolean_radio_button(@object_name, method, tag_value, objectify_options(options))
    end
  end
end

if Object.const_defined?(:ActionView) && ActionView.const_defined?(:Base)
  ActionView::Base.send(:include, BooleanRadioButton)
end