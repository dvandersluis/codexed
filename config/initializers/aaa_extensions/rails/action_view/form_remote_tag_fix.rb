ActionView::Base.class_eval do
  # Fix for form_remote_tag that adds custom parameters
  def form_remote_tag(options = {}, &block)
    options[:form] = true unless options[:submit] or options[:with] 

    options[:html] ||= {}
    options[:html][:onsubmit] = 
      (options[:html][:onsubmit] ? options[:html][:onsubmit] + "; " : "") + 
      "#{remote_function(options)}; return false;"

    form_tag(options[:html].delete(:action) || url_for(options[:url]), options[:html], &block)
  end
  alias_method :remote_form_tag, :form_remote_tag
end