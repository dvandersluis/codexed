require 'autosized_form_builder'

#
# This will add:
#  - autosized_form_for
#  - autosized_fields_for
#  - autosized_form_remote_for
#  - autosized_remote_form_for
#
[:form_for, :fields_for, :form_remote_for, :remote_form_for].each do |meth|
  code = <<-EOT
    def autosized_#{meth}(object_name, *args, &proc)
      options = args.last.is_a?(Hash) ? args.pop : {}
      options.update(:builder => LostInCode::AutosizedFormBuilder)
      #{meth}(object_name, *(args << options), &proc)
    end
  EOT
  ActionView::Base.module_eval(code, __FILE__, __LINE__)
end
