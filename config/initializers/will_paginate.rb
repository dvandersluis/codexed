module WillPaginate
  module ViewHelpers
    @@pagination_options = {
      :class        => 'pagination',
      :first_label  => '&laquo; First',
      :previous_label   => '&lsaquo; Previous',
      :next_label   => 'Next &rsaquo;',
      :last_label   => 'Last &raquo;',
      :jump_label   => 'Jump to Page:',
      :go_label     => 'Go',
      :inner_window => 4, # links around the current page
      :outer_window => 1, # links around beginning and end
      :separator    => ' ', # single space is friendly to spiders and non-graphic browsers
      :param_name   => :page,
      :params       => { 'per_page' => nil },
      :renderer     => 'WillPaginate::LinkRenderer',
      :page_links   => true,
      :container    => true
    }
  end
end

class JumpListLinkRenderer < WillPaginate::LinkRenderer
  def to_html
    html = []

    html.push page_link_or_span(1, 'disabled prev_page', @options[:first_label])
    html.push page_link_or_span(@collection.previous_page, 'disabled prev_page', @options[:previous_label])

    page_array = (1..@collection.total_pages).to_a
    html.push @template.content_tag(:span, @options[:jump_label], {:class => 'jump'})
    html.push @template.select_tag(
      @options[:param_name],
      @template.options_for_select(page_array, @collection.current_page),
      {
        :class => 'jump',
        :onchange => "location.href = '#{url_for('_p_')}'.replace(\'_p_\', this.value);"
      }
    )
    html.push @template.submit_tag(@options[:go_label], {:id => 'pagination_jump_submit'})
    html.push @template.hidden_field_tag("authenticity_token", @template.form_authenticity_token)

    html.push page_link_or_span(@collection.next_page, 'disabled next_page', @options[:next_label])
    html.push page_link_or_span(@collection.total_pages, 'disabled next_page', @options[:last_label])

    html.push @template.javascript_tag("$('pagination_jump_submit').hide();")
    html = html.join(@options[:separator])
    form = @template.content_tag(:form, html, { :class => 'jump', :method => 'post' })
    
    @options[:container] ? @template.content_tag(:div, form, html_attributes) : form
  end
end

module WillPaginate::Finder::ClassMethods
  # Patch paginated_each so that if you pass a :limit it caps how many records are iterated through in total
  def paginated_each(options = {})
    limit = options.delete(:limit)
    options = { :order => 'id', :page => 1 }.merge options
    options[:page] = options[:page].to_i
    options[:total_entries] = 0 # skip the individual count queries
    total = 0
    
    begin 
      collection = paginate(options)
      with_exclusive_scope(:find => {}) do
        # using exclusive scope so that the block is yielded in scope-free context
        total += collection.each { |item| yield item }.size
      end
      options[:page] += 1
    end until collection.size < collection.per_page or (limit and total + collection.per_page > limit)
    
    total
  end
end