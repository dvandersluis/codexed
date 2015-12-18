module Admin::PostsHelper
  def post_form_options
    form_options = {
      :html => {
        :id => "#{@post.full_type}_form", 
        :class => "entry_form #{@post.errors.empty? ? 'valid' : 'invalid'}"
      }
    }
    if @post.new_record?
      form_options[:url] = { :action => 'create' }
      form_options[:html][:method] = 'post'
    else
      form_options[:url] = { :action => 'update', :id => @post.id }
      form_options[:html][:method] = 'put'
    end
    form_options[:url].merge!(:pk => params[:pk])
    form_options
  end

  def categories_select(object, name, categories)
    table_content = ""
    categories.each do |category|
      category.self_and_descendants.sort_by(&:lft).each do |c|
        cell = check_box_tag("#{object.to_s}[#{name.to_s}][]",
            c.id,
            @post.category_ids.include?(c.id),
            :style => "margin-right: 5px; width: auto;",
            :id => "#{object.to_s}_#{name.to_s}_#{c.id}"
          )
        cell << h(c.name)
        cell << image_tag('icons/lock12.png', {
          :style => 'margin-left: 5px;',
          :title => t('controllers.admin.categories.index.private_category')
        }) if c.private?
        
        table_content << content_tag(:tr,
          content_tag(:td, cell,
            :style => "padding-left: #{16 * c.level}px; whitespace: nowrap",
            :nowrap => "nowrap"
          ),
          :id => "#{object.to_s}_#{name.to_s}_row_#{c.id}"
        )
      end
    end
    
    tbody = content_tag(:tbody, table_content)
    content_tag(:table, tbody, :id => "#{object}_#{name}_table")
  end
end
