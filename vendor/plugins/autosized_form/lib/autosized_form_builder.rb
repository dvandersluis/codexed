module LostInCode
  #
  # Custom form builder that sets the 'size' and 'maxlength' of textfields to match
  # the specified length of fields in the database
  #
  # See <http://www.aldenta.com/2006/09/19/writing-a-custom-formbuilder-in-rails/>
  #
  class AutosizedFormBuilder < ActionView::Helpers::FormBuilder
    MAX_LENGTH = 30
    def text_field(method, options={})
      object = @object || @template.instance_variable_get("@#{@object_name}")
      klass = object.class
      column = klass.columns_hash[method.to_s]
      maxlength = column ? column.limit : MAX_LENGTH
      size = (maxlength >= MAX_LENGTH) ? MAX_LENGTH : maxlength
      super(method, { :size => size, :maxlength => maxlength }.merge(options))
    end
  end
end
