class ActionView::Base
  # Fix label_tag so that it accepts a block
  # Unfortunately it is impossible to override the FormBuilder method as well right now
  def label_tag(name=nil, text=nil, options={}, &block)
    content = text || name || ""
    options.stringify_keys!
    options.reverse_merge!("for" => name) if name
    content_tag(:label, content, options, &block)
  end
end