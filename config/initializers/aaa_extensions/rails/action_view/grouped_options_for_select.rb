if Object.const_defined?(:ActionView) && ActionView.const_defined?(:Base)
  module ActionView::Helpers::FormOptionsHelper
    # From http://rails.lighthouseapp.com/projects/8994-ruby-on-rails/tickets/977
    #
    # Returns a string of <tt><option></tt> tags, like <tt>options_for_select</tt>, but
    # wraps them with <tt><optgroup></tt> tags.
    #
    # Parameters:
    # * +grouped_options+ - Accepts a nested array or hash of strings.  The first value serves as the 
    #   <tt><optgroup></tt> label while the second value must be an array of options. The second value can be a
    #   nested array of text-value pairs. See <tt>options_for_select</tt> for more info.
    #    Ex. ["North America",[["United States","US"],["Canada","CA"]]]
    # * +selected_key+ - A value equal to the +value+ attribute for one of the <tt><option></tt> tags,
    #   which will have the +selected+ attribute set. Note: It is possible for this value to match multiple options
    #   as you might have the same option in multiple groups.  Each will then get <tt>selected="selected"</tt>.
    # * +prompt+ - set to true or a prompt string. When the select element doesn't have a value yet, this
    #   prepends an option with a generic prompt "Please select" or the given prompt string.
    #
    #
    # Sample usage (Array):
    #   grouped_options = [
    #    ['North America',
    #      [['United States','US'],'Canada']],
    #    ['Europe',
    #      ['Denmark','Germany','France']]
    #   ]
    #   grouped_options_for_select(grouped_options)
    #
    # Sample usage (Hash):
    #   grouped_options = {
    #    'North America' => [['United States','US], 'Canada'],
    #    'Europe' => ['Denmark','Germany','France']
    #   }
    #   grouped_options_for_select(grouped_options)
    #
    # Possible output:
    #   <optgroup label="Europe">
    #     <option value="Denmark">Denmark</option>
    #     <option value="Germany">Germany</option>
    #     <option value="France">France</option>
    #   </optgroup>
    #   <optgroup label="North America">
    #     <option value="US">United States</option>
    #     <option value="Canada">Canada</option>
    #   </optgroup>
    #
    # <b>Note:</b> Only the <tt><optgroup></tt> and <tt><option></tt> tags are returned, so you still have to
    # wrap the output in an appropriate <tt><select></tt> tag.
    def grouped_options_for_select(grouped_options, selected_key = nil, prompt = nil)
      str = String.new
      unless prompt.nil?
         prompt.kind_of?(String) ? prompt : 'Please select'
         str += content_tag :option, prompt, :value => ""
      end
      grouped_options = grouped_options.sort if grouped_options.is_a? Hash
      for group in grouped_options
        if group[0].blank?
          str += options_for_select(group[1], selected_key)
        else
          str += content_tag :optgroup, options_for_select(group[1], selected_key), :label => group[0]
        end
      end
      str
    end
  end
end