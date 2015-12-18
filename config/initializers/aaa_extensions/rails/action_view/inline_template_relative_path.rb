ActionView::InlineTemplate.class_eval do
  # Define relative_path so when we use ActionView::InlineTemplate in Template.run_through_erb,
  # and ActionView has trouble rendering it, we can fool ActionView::TemplateError into thinking
  # the template is a regular ActionView::Template
  def relative_path
    "(no path)"
  end
end