module ApplicationHelper
  
  # Global view stuff
  
  def base_includes
    base_stylesheets + "\n" +
    base_javascripts + "\n" +
    base_smart_assets
  end
  
  def base_stylesheets
    stylesheet_link_tag('reset', 'base', 'application') + "\n" +
    "<!--[if IE]>\n" + stylesheet_link_tag('application.ie') + "\n<![endif]-->\n" +
    "<!--[if IE 6]>\n" + stylesheet_link_tag('application.ie6') + "\n<![endif]-->\n" +
    stylesheet_link_tag('messages')
  end
  
  def base_javascripts
    javascript_include_tag *%w(prototype effects)
  end
  
  def base_smart_assets
    smart_asset_includes(:except => 'application.css') + "\n" +
    smart_asset_runtime_includes
  end
  
  def include_facebox
    add_to_stylesheets 'facebox'
    add_to_javascripts 'facebox'
  end
  
  def main_div_attributes
    @hide_sidebar ? { :style => 'margin: 0' } : {}
  end
  
  def show_language_nag_notice?
    user = current_user or return false
    journal = user.journal
    return false if params[:controller] == 'admin/options' and params[:action] == 'account'
    return false if cookies[:dismiss_language_nag_notice]
    return (journal.language.nil? and journal.listed? and !journal.private? and !journal.entries.empty?)
  end

  def show_survey_nag_notice?
    return false
    
    # Survey is closed for now
    user = current_user or return false
    return false if cookies[:dismiss_survey_nag_notice]
    true
  end
  
  def show_birthday_nag_notice?
    user = current_user or return false
    journal = user.journal

    return false if params[:controller] == 'admin/options' and params[:action] == 'account'
    return false if cookies[:dismiss_birthday_nag_notice]
    user.birthday.nil? and journal.listed? and !journal.private?
  end

  def today_is_my_birthday?
    user = current_user or return false
    !user.birthday.nil? and user.birthday.is_today?
  end

  #----
  
  # Message div helpers
  
  # This is a handy way of creating a div you would use to display a message to the
  # user after some action -- maybe an informational message, or a message indicating
  # success or failure -- and doing so in a consistent way.
  #
  # The first argument indicates what kind of message it is: :notice, :success, or :error.
  # This also chooses what kind of icon to show at the beginning of the message.
  #
  # The value of the div can be specified in the second argument, or you can also
  # pass a block that will get evaluated.
  #
  # Pass a hash for the third argument to specify the options. They are:
  # * :unless_blank - true by default, which means the div won't be output if the value
  #                   you passed ends up being blank. Set to false to override.
  # * :image        - true by default, which means an icon will appear corresponding
  #                   to the message type, to the left of the message. Set to false
  #                   to override.
  #
  # Finally, pass a hash for the fourth argument to specify HTML options for the div
  # itself. By default, it will get a class name corresponding to the message type
  # (so "notice", "success", or "error").
  #
  # === Examples
  #
  #   <%= message_div_for :notice, flash[:notice] %>
  #
  #   <%= message_div_for :success, @success, {}, :style => "border: 1px solid green" %>
  #
  #   <% message_div_for :error do %>
  #     Some content goes here
  #   <% end %>
  def message_div_for(kind, *args, &block)
    div_options = args.extract_options!
    options = args.extract_options!
    value = args.first
    
    kind = kind.to_sym
    options[:unless_blank] = true unless options.include?(:unless_blank)
    options[:image] = true if [:notice, :success, :error].include?(kind) && !options.include?(:image)
    div_options[:class] ||= kind.to_s
    
    div_content = block ? capture_haml(&block).chomp : value
    return "" if options[:unless_blank] && div_content.blank?
    
    image_content = ""
    if options.delete(:image)
      image = case kind
        when :notice  then "information"
        when :success then "accept"
        when :error   then "exclamation"
      end
      image_div_options = { :style => 'float: left; width: 16px; padding: 3px;' }
      image_content = content_tag(:div, image_tag("icons/#{image}.png", :class => 'icon', :alt => t("general.messages.#{kind}")), image_div_options)
    end
    
    content_tag(:div, image_content + content_tag(:div, div_content), div_options)
  end

  def message_divs
    message_div_for(:success, (flash[:success] || @success)) +
    message_div_for(:error,   (flash[:error]   || @error)) +
    message_div_for(:notice,  (flash[:notice]  || @notice))
  end
  
  #----
  
  # Misc stuff
  
  def ordered_error_messages_for(model, *attributes)
    # Instead of error_messages_for, output error messages in a given order
    if model.errors.count > 0
      options = attributes.extract_options!.symbolize_keys
      heading = options[:heading] || 'form.oops'
      message = options[:message] || 'has_errors'

      error_messages = ''
      attributes.each do |attr|
        if !model.errors[attr].blank?
          attr_name = model.class.human_attribute_name(attr.to_s)
          error_messages << content_tag(:li, error_message_on(model, attr, attr_name.blank? ? "" : attr_name + "&nbsp;"))
        end
      end

      contents = ''
      contents << content_tag(:h2, t(heading))
      contents << content_tag(:p, t(message))
      contents << content_tag(:ul, error_messages)

      content_tag(:div, contents, { :class => 'errorExplanation', :id => 'errorExplanation' })
    end
  end

  def distance_of_time_in_more_words(from_time, to_time = 0)
    from_time = from_time.to_time if from_time.respond_to?(:to_time)
    to_time = to_time.to_time if to_time.respond_to?(:to_time)
    diff = to_time - from_time
    interval_names = %w(hours minutes seconds)
    parts = interval_names.map do |name|
      interval = 1.send(name)
      number, diff = diff.abs.divmod(interval)
      t(:"x_#{name}", :scope => "datetime.distance_in_words", :count => number) unless number == 0
    end
    sentence = parts.compact.to_sentence
    sentence.empty? ? "" : t("datetime.distance_in_words.about").capitalize + " " + sentence
  end
  def time_ago_in_more_words(from_time)
    distance_of_time_in_more_words(from_time, Time.now)
  end
  
  # Not sure why this doesn't exist
  def button_tag(value, options = {})
    options.stringify_keys!
    tag :input, { "type" => "button", "name" => (options[:name] || "button"), "value" => value }.merge(options)
  end
  
  def nl2br(text)
    text.gsub(/\n/, "<br />")
  end
  
  def tabbed(tabs, &block)
    add_to_stylesheets 'tabs'
    out = ""
    out << content_tag(:div, :id => 'tabs_header') {
      content_tag(:ul) {
        tabs.inject("") do |out2, (content, actions)|
          actions = [actions].flatten.map {|a| url_for(:action => a, :only_path => true) }
          current = actions.find {|a| a == request.request_uri }
          out2 << content_tag(:li) {
            if current
              content_tag(:span, content)
            else
              link_to(content, actions.first)
            end
          }
        end
      }
    }
    out << content_tag(:div, :id => 'tabs_content') {
      content_tag(:div, :id => 'tabs_content_inner') { capture(&block) }
    }
    concat(out)
  end

  def redmine_link(*issues)
    links = []
    issues.each do |issue|
      links.push(link_to("##{issue}", "http://redmine.codexed.com/issues/show/#{issue}", :popup => true))
    end
    "[" + links.join(", ") + "]"
  end
  alias :rl :redmine_link

  # Nested Set helpers
  # This is a copy of the helper from the awesome_nested_set plugin but modified to sort the 
  # results properly.
  def nested_set_options(class_or_item, mover = nil)
    class_or_item = class_or_item.roots if class_or_item.is_a?(Class)
    items = Array(class_or_item)
    result = []
    items.each do |root|
      result += root.self_and_descendants.sort_by(&:lft).map do |i|
        if mover.nil? || mover.new_record? || mover.move_possible?(i)
          [yield(i), i.id]
        end
      end.compact
    end
    result
  end
end
