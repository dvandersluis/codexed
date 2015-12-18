# Fix form_tag so that the "hidden" div that holds the forgery protection token
# is set to display: inline so that in case the form itself is set to display: inline
# it doesn't cause a line break
if Object.const_defined?(:ActionView) && ActionView.const_defined?(:Base)
  class ActionView::Base
  private
    def extra_tags_for_form(html_options)
      case method = html_options.delete("method").to_s
        when /^get$/i # must be case-insentive, but can't use downcase as might be nil
          html_options["method"] = "get"
          ''
        when /^post$/i, "", nil
          html_options["method"] = "post"
          protect_against_forgery? ? content_tag(:div, token_tag, :style => 'margin:0;padding:0;display:inline') : ''
        else
          html_options["method"] = "post"
          content_tag(:div, tag(:input, :type => "hidden", :name => "_method", :value => method) + token_tag, :style => 'margin:0;padding:0;display:inline')
      end
    end
  end
end