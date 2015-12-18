module PrefabHelper
  # Used by prefabs/form
  def link_to_prefab_preview(name)
    link_to_remote(
      image_tag('icons/magnifier.png', :valign => 'absmiddle'),
      {
        :url => { :action => 'preview', :prefab => name },
        :update => 'preview',
        :loading => "ajax_loading()",
        :failure => "ajax_failed()",
        :complete => "ajax_complete(request)" #evaluate_remote_response
      },
      :href => journal_page_path(:user => @user, :permaname => 'lorem', :prefab => name),
      :style => 'border: none', :target => '_blank'
    )
  end

  def color_options(colors, descriptions, path, indent = 0)
    # Recursively build a table of color options, since options can be nested.
    # There are two special options in the config file:
    # _order: Specifies the order to display children of an option
    # _: Specifies the title text for a option category/header
    out = ""
    d = descriptions.include?(:_order) ? descriptions._order : descriptions
    d.reject!{|k,v| k =~ /^_/}

    @path_len ||= path.gsub(/[\[\]]+/, '.').split(".").length
    @counter ||= 0

    out << '<table class="form">'
    d.each do |k, v|
      if v.is_a? ConfigurationHash or (descriptions[k].is_a? ConfigurationHash and !descriptions[k].include?(:_note))
        out << '</table>'
        out << content_tag(:h3, descriptions[k]._)
        out << color_options(colors[k], descriptions[k], path + "[#{k}]", indent + 1)
      else
        dotted_path = path.gsub(/[\[\]]+/, '.').split(".")
        name = "#{dotted_path.join('.')}.#{k}".split('.')[@path_len..-1].join('.') 
        rgb = colors[k].to_color
        text_col = rgb.brightness < 0.5 ? '#FFFFFF' : '#000000'
        
        @counter += 1
        td = ""
        td << text_field_tag(path + "[#{k}]", colors[k], {:maxlength => 7, :class => "change_color_input", :style => "width: 75px; color: #{text_col}; background-color: #{colors[k].to_s}", :onkeypress => 'if (force_allowed_chars(event, /[#0-9a-f]/i)) force_uppercase(event);' }) 
        td << submit_tag(t(:change_color), {:class => 'change_color_button', :style => 'margin-left: 5px;', :name => "change_color[#{name}]"})
        
        #out << content_tag(:div, descriptions[k], :class => 'header')
        if descriptions[k].is_a? ConfigurationHash 
          if descriptions[k].include? :_note
            out << content_tag(:tr) {
              content_tag(:th, descriptions[k]["_"], :rowspan => 2, :style => 'vertical-align: top;') +
              content_tag(:td, td)
            } + content_tag(:tr) {
              content_tag(:td, descriptions[k]["_note"], :style => 'font-style: italic;')
            }
          else
            throw ArgumentError, "Colors should only have a _ key if they have a note!"
          end
        else
          out << content_tag(:tr) {
            content_tag(:th, descriptions[k]) +
            content_tag(:td, td)
          }
        end
      end
    end
    out << '</table>'
    out
  end

  def font_picker(name, family, size)
    out = ""

    out << content_tag(:div, :style => "float: left; padding-right: 5px;") do
      content_tag(:select, :name => name + "[family]", :id => name.gsub(/[\[\]]+/, '-') + '-family', :class => 'font_picker') do
        out2 = ""
        fonts = %W(Arial Helvetica Times-New-Roman Times Courier-New Courier Verdana Georgia Comic-Sans-MS Trebuchet Impact Arial-Black Palatino Garamond Bookman Avant-Garde Tahoma)
        fonts.sort.each do |font| 
          font.gsub!(/-/, " ")
          option_attrs = { :value => font, :style => "font-family: #{font};" }
          option_attrs[:selected] = "selected" if font == family
          out2 << content_tag(:option, font, option_attrs)
        end
        out2
      end
    end

    out << select_driven_slider_tag(name + "[px]", (8..64).map{ |s| [s.to_s + "px", s] }, size, { "min" => [8, size].min, "max" => [64, size].max, "labelValue" => "value + 'px'", "defaultLabelValue" => size.to_s + "px" }) if size
    out
  end

  def non_js_color_picker(prefab_name, name, action = "new")
    full_hash_parts = %w(00 33 66 99 AA CC EE FF)
    hash_parts = [%w(33 66 99 CC FF), %w(33 99 CC)]
    color_map = []

    # Collect the colors to display
    color_map.push full_hash_parts.collect{|hash| hash*3} # Greyscale
    color_map.push(hash_parts[0].collect{|hash| '00'*2 + hash} + hash_parts[1].collect{|hash| hash*2 + 'FF'}) # Blue
    color_map.push(hash_parts[0].collect{|hash| '00' + hash + '00'} + hash_parts[1].collect{|hash| hash + 'FF' + hash}) # Red
    color_map.push(hash_parts[0].collect{|hash| hash + '00' * 2} + hash_parts[1].collect{|hash| 'FF' + hash*2}) # Green
    color_map.push(hash_parts[0].collect{|hash| hash*2 + '00'} + hash_parts[1].collect{|hash| 'FF'*2 + hash}) # Yellow
    color_map.push(hash_parts[0].collect{|hash| '00' + hash*2} + hash_parts[1].collect{|hash| hash + 'FF'*2}) # Cyan
    color_map.push(hash_parts[0].collect{|hash| hash + '00' + hash} + hash_parts[1].collect{|hash| 'FF' + hash + 'FF'}) # Magenta

    color_link_params = {:action => action, :cname => name, :change_color => 1}
    color_link_params[:name] = prefab_name if action == "new"
    
    out = "" 
    out << content_tag(:table) {
      color_map.collect do |row|
        content_tag(:tr, :class => 'color-picker-row') {
          row.collect do |color|
            content_tag(:td) {
              color_link_params[:cval] = "##{color}"
              link_to "", color_link_params, { :style => "background-color: ##{color}" }
            } 
          end
        }
      end
    }
    out
  end
end
