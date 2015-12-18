require 'colorist'

class Admin::PrefabsController < Admin::TemplatesController
  include Colorist

  skip_before_filter :redirect_to_prefab # Avoid a redirection loop
  
  def index
    @type = flash[:templates_type] || 'p'
    super
  end

  def list
    @sort_by = %w(name newest popularity).include?(params[:sort]) ? params[:sort] : "name"

    @prefabs = Prefab.skeleton :all
    @popularity = @prefabs.sort_by{ |p| p.uses }.reverse
    @newest = @prefabs.sort_by{ |p| p.config.meta.created || Date.new }.reverse

    @prefabs = case @sort_by
      when 'popularity' then @popularity
      when 'newest' then @newest
      else @prefabs
    end
  end
  
  def new
    @prefab = flash[:prefab] || @journal.prefabs.build(:prefab_name => params[:name])
    redirect_to :action => 'list' and return if @prefab.nil? or @prefab.skeleton.nil?
    setup_prefab_form
  end

  def create
    @prefab = @journal.prefabs.build
    
    if params[:cancel] or params[:return]  # hmm, params[:return] here and not in 'update' ?
      clear_preview_data(params[:pk])
      if params[:cancel]
        flash[:notice] = t(:new_prefab_canceled)
        redirect_to :action => 'index'
      else
        redirect_to :action => 'list'
      end
      return
    end

    handle_form_post
  end

  def edit
    @prefab = flash[:prefab] || find_prefab(:missing_record_to_edit) or return
    setup_prefab_form
  end

  def update
    @prefab = find_prefab(:missing_record_to_edit) or return
    @config = @prefab.skeleton.config.deep_merge(@prefab.config)
    
    if params[:cancel]
      clear_preview_data(params[:pk])
      flash[:notice] = t(:changes_to_prefab_not_saved, :name => h(@prefab.name))
      clear_preview_data(params[:pk])
      redirect_to :action => 'index'
      return
    end
    
    if params[:convert]
      convert_prefab(@prefab)
      return
    end

    handle_form_post
  end
  
  def delete
    @prefab = find_template(:missing_record_to_delete) or return
  end
  
  # For multiple value variables, add another row through AJAX
  def add_varlist_row
    if !request.xhr?
      redirect_to :action => :index
    end

    @config = @journal.prefabs.build(:prefab_name => params[:name]).config
    render(:update) do |page|
      page.insert_html :before, params[:before], :partial => "varlist", :locals => { :varlist => {}, :parent => params[:parent], :multiple => params[:multiple] }
    end
  end

  def preview
    pd = preview_data(params[:pk])
    if pd.nil?
      respond_to do |format|
        format.html { redirect_to :action => :index }
        format.any { render :nothing => true, :status => "404 Not Found" }
      end
      return
    end
    
    @prefab = @journal.prefabs.find_by_id(params[:id]) || @journal.prefabs.build
    @prefab.attributes = pd[:attrs]
    @prefab.config.deep_merge!(pd[:config])
    template = @prefab

    # Add a topbar that reminds user this is a preview
    style_tag = <<EOT
<style type="text/css">
  body { margin: 0; padding: 0 }
  #cdx__topbar__ { background-color: #333; color: white; height: 20px; padding: 5px 9px; font-family: Verdana; font-size: 13px; border-bottom: 1px solid black; text-align: center; }
  #cdx__topbar__ form, #cdx__topbar__ form div { display: inline }
  #cdx__topbar__ input { vertical-align: middle }
  #cdx__topbar__ a { color: #F4FF9E }
  #cdx__body__ { padding: 1em; position: relative }
</style>
EOT

    # we use render_to_string here so we can use form_tag, which automatically includes the authenticity token
    @preview_key = params[:pk]
    topbar_div = render_to_string(:inline => %|
<div id="cdx__topbar__">
  #{t(:looking_at_a_preview, :record => t('models.prefab', :count => 1).downcase, :scope => 'general.form.preview_top')}&nbsp;
  <% form_for([:admin, @prefab]) do %>
    <input type="hidden" name="pk" value="<%= @preview_key %>" />
    <input type="submit" name="save_and_return" value="#{t(:save_and_finish_editing, :record => t('models.prefab', :count => 1).downcase, :scope => 'general.form.preview_top')}" />
  <% end %>
  #{t(:or)}
  <% url = (@prefab.new_record? ? { :action => 'new', :name => @prefab.prefab_name } : { :action => 'edit', :id => @prefab.id }).merge(:pk => @preview_key) %>
  <%= link_to "#{t('form.preview_top.continue_editing')}", url %>
</div>
    |)

    style_included = false
    topbar_included = false

    # If <head> is present in the template, insert the style tag last inside it
    template.raw_content = template.raw_content.sub(%r|(<head[^>]*>)(.+)</head>|m) {
      style_included = true
      [$1, $2, style_tag, "</head>"].join("\n")
    }

    # If a <body> tag is present in the template, replace it with:
    # - the style tag (unless it's already been included, above)
    # - the topbar div
    # - the contents of <body>, wrapped in a div
    template.raw_content = template.raw_content.sub(%r|(<body[^>]*>)(.+)</body>|m) {
      ret = [$1, (style_tag unless style_included), topbar_div, '<div id="cdx__body__">', $2, '</div>', '</body>'].join("\n")
      style_included = true
      topbar_included = true
      ret
    }

    # If a <html> tag is present in the template, replace it with:
    # - the style tag (unless it's already been included, above)
    # - the topbar div (unless it's already been included, above)
    # - the contents of <html>, wrapped in a div
    #
    # Otherwise, replace the entire template with:
    # - the style tag (unless it's already been included, above)
    # - the topbar div (unless it's already been included, above)
    # - the entire template, including any changes we've made so far, wrapped in a <div>
    unless style_included && topbar_included
      template.raw_content = template.raw_content.sub(%r|(<html[^>]*>)(.+)</html>|m) {
        [$1, (style_tag unless style_included), (topbar_div unless topbar_included), '<div id="cdx__body__">', $2, '</div>', '</html>'].join("\n")
      }
      if Regexp.last_match.nil?
        template.raw_content = template.raw_content.sub(/^(.*)$/m) {
          [(style_tag unless style_included), (topbar_div unless topbar_included), '<div id="cdx__body__">', $1, '</div>'].join("\n")
        }
      end
    end
    
    # Notice we pass the current ActionView instance to the Papyrus template
    # This is so we can use it to pass the Papyrus template through ERB gaining access to ActionView stuff if need be
    ivars = { 'template' => @template, 'user' => current_user }
    entry = @journal.entries.find_fake_by_name('lorem')
    render :text => entry.render_with_template(template, current_user, ivars)
  end

  def convert
    @prefab = find_prefab(t(:missing_prefab_to_convert)) or return
    if request.post?
      convert_prefab(@prefab) 
    else
      # show view
    end
  end
  
private
  def find_prefab(*args)
    error_key = args.pop
    other_prefab = args.first
    prefab = other_prefab || @journal.prefabs.find_by_id(params[:id])
    if prefab.nil?
      flash[:error] = error_key.is_a?(Symbol) ? t(error_key, :record => t('models.prefab', :count => 1).downcase, :scope => 'general.messages') : error_key
      redirect_to :action => 'index'
      return false
    end
    prefab
  end

  def setup_prefab_form
    if pk = params[:pk] and pd = preview_data(pk)
      @prefab.attributes = pd[:attrs]
      @prefab.config.deep_merge!(pd[:config])
    end
    @config = @prefab.skeleton.config.deep_merge(@prefab.config)

    if params[:change_color] && !params[:cval].blank?
      cval = (params[:cval] =~ /^#/) ? params[:cval] : '#'+params[:cval]
      cname = params[:cname]
      # Make sure the given colour is proper
      if cval.is_color?
        eval("@config.customization.colors.#{cname} = '#{cval}'")
      end
    end
  
    render :action => 'form'
  end

  def handle_form_post
    # Params depend on whether we're coming from a prefab or not
    if params[:prefab]
      prefab_options = params[:prefab]
      config_options = params[:config]
    elsif pd = preview_data(params[:pk])
      prefab_options = pd[:attrs]
      config_options = pd[:config]
    else
      flash[:error] = t('messages.invalid_update', :record => t('models.prefab', :count => 1).downcase)
      redirect_to :action => :index and return
    end

    # Update the prefab object
    @prefab.attributes = prefab_attrs = prefab_options 
    @prefab.config.deep_merge!(config_options) if config_options
    @prefab.config.prefab_name = prefab_options[:prefab_name]
    @prefab.config.name = prefab_options[:name]

    @prefab.config.reset_invalid_colors!
    @prefab.config.cleanup_var_arrays!

    if params[:preview] or params[:change_color]
      pk = set_preview_data({:attrs => prefab_attrs, :config => @prefab.config.to_hash}, @prefab)
      
      if params[:preview]
        redirect_to :action => 'preview', :pk => pk
      elsif params[:change_color]
        change_color
      end
      
      return
    end

    save_prefab
  end

  def save_prefab
    action = params[:action]
    
    if @prefab.valid?
      @prefab.config.save
      @prefab.save
      
      if @prefab.make_default?
        @journal.config.default.template = @prefab.name
        @journal.config.save
        flash[:notice] = t(:template_set_as_default, :name => @prefab.name)
      end
      
      message = t("prefab_#{action}d", :name => @prefab.name) + %| <a href="#{@prefab.url}">| + t('messages.check_it_out') + '</a>'
      flash[:success] = message
      
      clear_preview_data(params[:pk])
      redirect_to :action => 'index'
    else
      flash[:prefab] = @prefab
      if action == 'update'
        redirect_to :action => 'edit', :id => @prefab.id
      else
        redirect_to :action => 'new', :name => @prefab.prefab_name
      end
    end
  end
  
  def change_color
    @color_name = params[:change_color].keys.first.to_s
    color_parts = @color_name.split('.')
    @color_desc = []

    @config = Prefab.skeleton(@prefab.prefab_name).config

    for i in (0..color_parts.length-1)
      hash = eval('@config.descriptions.colors.' + color_parts[0..i].join('.'))
      if hash.is_a? String
        @color_desc.push hash
      elsif hash.is_a? ConfigurationHash and hash.include? :_
        @color_desc.push hash._
      end
    end

    render :action => 'change_color'
  end
  
  def convert_prefab(prefab)
    if params[:cancel]
      flash[:notice] = t('convert.canceled', :name => h(prefab.name))
    else
      prefab.convert_to_template
      flash[:success] = t('convert.succeeded', :name => h(prefab.name))
    end
    redirect_to :action => 'index'
  end
  
  def propagate_pagination_vars
    flash.keep(:templates_per_page)
    flash.keep(:templates_page)
    flash.keep(:templates_type)
  end
  
  def unencoded_preview_key(prefab)
    return "" if prefab.nil?
    "__#{prefab.id || Time.now.to_i}__"
  end
  
end
