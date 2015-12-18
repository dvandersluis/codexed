module ActionView
  module Helpers
    module FormOptionsHelper
      # Updated to allow text to not be html escaped
      def options_for_select(container, selected = nil, html_escape_text = true)
        container = container.to_a if Hash === container
        selected, disabled = extract_selected_and_disabled(selected)

        options_for_select = container.inject([]) do |options, element|
          text, value = option_text_and_value(element)
          selected_attribute = ' selected="selected"' if option_value_selected?(value, selected)
          disabled_attribute = ' disabled="disabled"' if disabled && option_value_selected?(value, disabled)
          if html_escape_text
            options << %(<option value="#{html_escape(value.to_s)}"#{selected_attribute}#{disabled_attribute}>#{html_escape(text.to_s)}</option>)
          else
            options << %(<option value="#{html_escape(value.to_s)}"#{selected_attribute}#{disabled_attribute}>#{text.to_s}</option>)
          end
        end

        options_for_select.join("\n")
      end
    end

    class InstanceTag #:nodoc:
      def to_select_tag(choices, options, html_options)
        html_options = html_options.stringify_keys
        add_default_name_and_id(html_options)
        value = value(object)
        selected_value = options.has_key?(:selected) ? options[:selected] : value
        disabled_value = options.has_key?(:disabled) ? options[:disabled] : nil
        html_escape_text = options.has_key?(:html_escape_text) ? options[:html_escape_text] : true
        content_tag("select", add_options(options_for_select(choices, {:selected => selected_value, :disabled => disabled_value}, html_escape_text), options, selected_value), html_options)
      end
    end
  end
end
