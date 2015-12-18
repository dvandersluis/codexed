# Note that we can't use @template, because Rails uses that internally
# So we use @tpl instead

class Admin::TemplatesController < Admin::BaseController
  
  before_filter :set_user_and_journal
  before_filter :restrict_type
  before_filter :propagate_pagination_vars, :except => :index
  
  cache_sweeper :template_sweeper

  def show
    redirect_to :action => :index, :type => flash[:templates_type]
  end
  
  def index
    @selectable_views = [[t(:all), 'all', admin_templates_url(:type => "all")], [t(:custom), 'c', admin_templates_url(:type => 'c')], [t(:prefabs), 'p', admin_templates_url(:type => 'p')]]
    @page = params[:page] || flash[:templates_page] || 1
    @type = params[:type] || flash[:templates_type] || 'c' if @type.nil?
    
    @type = @type.downcase

    # If the type was changed, go back to page one.
    @page = 1 if !flash[:templates_type].nil? and params[:type] != flash[:templates_type]

    if params[:per_page] and params[:per_page] =~ /^[1-9]\d*$/
      @journal.config.ui.pagination.template = params[:per_page]
      @journal.config.save
    end

    @per_page = @journal.config.ui.pagination.template
    redirect_to(:action => 'index', :type => @type) and return if @page.to_i < 1

    flash[:templates_type] = @type
    flash[:templates_page] = @page
    
    collection = (@type == 'p') ? @journal.prefabs : @journal.templates
    
    if @type != 'p' && @journal.templates.empty?
      # show the fallback template instead
      @templates = WillPaginate::Collection.create(@page, @per_page) do |pager|
        pager.replace([ @journal.fallback_template ])
      end
      @showing_default_template = true
    else    
      @paginate_opts = {:page => @page, :per_page => @per_page, :order => 'name'}
      @paginate_opts.merge!({:conditions => "type = 'Template'"}) if @type == 'c'

      if @journal.default_template.nil?
        @templates = collection.paginate @paginate_opts
      else
        @templates = collection.paginate @paginate_opts.merge!({:order => "id = #{@journal.default_template.id} DESC, name"})
      end
      if @templates.total_entries > 0 && @templates.out_of_bounds?
        redirect_to :action => 'index', :type => @type
        return
      end
    end

    hide_global_messages
    
    # this is here b/c this method is called by prefabs/index
    render :template => 'admin/templates/index'
  end
  
  def new
    if flash[:template]
      # oops, must have had an error while saving
      @tpl = flash[:template]
    else
      @tpl = @journal.templates.build
      if pk = params[:pk] and pd = preview_data(pk)
        @tpl.attributes = pd
      end
    end
    render :action => 'form'
  end
  
  def new_from_default
    if flash[:template]
      # oops, must have had an error while saving
      @tpl = flash[:template]
    else
      @tpl = @journal.templates.find_fake_by_name('main')
      if pk = params[:pk] and pd = preview_data(pk)
        @tpl.attributes = pd
      end
    end
    render :action => 'form'
  end
    
  def create
    if params[:cancel]
      clear_preview_data(params[:pk])
      flash[:notice] = t(:new_template_canceled)
      redirect_to :action => 'index', :type => flash[:templates_type]
      return
    end
    
    @tpl_attrs = params[:template] || preview_data(params[:pk])

    if @tpl_attrs.nil?
      flash[:error] = t('messages.invalid_create', :record => t('models.template', :count => 1).downcase)
      redirect_to :action => :index and return
    end

    @tpl = @journal.templates.build(@tpl_attrs)
    
    if params[:preview]
      pk = set_preview_data(@tpl_attrs, @tpl)
      redirect_to :action => 'preview', :pk => pk
      return
    end

    if @tpl.save
      post_save
    else
      flash[:template] = @tpl
      redirect_to :action => 'new'
    end
  end
  
  def edit
    if flash[:template]
      # oops, must have had an error while saving
      @tpl = flash[:template]
    else
      @tpl = find_template(:missing_record_to_edit) or return
      if pk = params[:pk] and pd = preview_data(pk)
        @tpl.attributes = pd
      end
    end

    if @tpl.prefab?
      propagate_pagination_vars   # didn't we already do this in the before_filter?
      redirect_to edit_admin_prefab_path(:id => @tpl.id)
      return
    end

    render :action => 'form'
  end

  def update
    @tpl = find_template(:missing_record_to_update) or return

    if params[:cancel]
      clear_preview_data(params[:pk])
      flash[:notice] = t(:changes_to_template_not_saved, :name => h(@tpl.name))
      redirect_to :action => 'index', :type => flash[:templates_type]
      return
    end
    
    @tpl.attributes = @tpl_attrs = params[:template] || preview_data(params[:pk])
    
    if @tpl_attrs.nil?
      flash[:error] = t('messages.invalid_update', :record => t('models.template', :count => 1).downcase)
      redirect_to :action => :index and return
    end

    if params[:preview]
      pk = set_preview_data(@tpl_attrs, @tpl)
      redirect_to :action => 'preview', :id => @tpl, :pk => pk
      return
    end

    if @tpl.save
      post_save
    else
      flash[:template] = @tpl
      redirect_to :action => 'edit', :id => @tpl
    end
  end
  
  def delete
    @tpl = find_template(:missing_record_to_delete) or return
  end
  
  # we don't technically need instance variables here but they come in handy when testing
  def destroy
    @tpl = find_template(:missing_record_to_delete) or return
    @tpl.destroy
    flash[:success] = t(:template_deleted, :name => h(@tpl.name))

    # if template was the default, remove it from config
    config = @journal.config
    if config.default.template == @tpl.name
      config.default.template = nil
      config.save
      flash[:notice] = t(:default_template_deleted) 
    end
    
    # if last template was deleted, indicate fallback template will be used
    if @journal.templates.empty?
      new_notice = t(:fallback_template_restored)
      # probably a better way to do this
      if flash[:notice]
        flash[:notice] << "<br />#{t("general.messages.also")}, #{new_notice[0].chr.downcase + new_notice[1..-1]}"
      else
        flash[:notice] = new_notice
      end
    end

    redirect_to :action => 'index', :type => flash[:templates_type]
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
    
    @tpl = @journal.templates.find_by_id(params[:id]) || @journal.templates.build
    @tpl.attributes = pd
    template = @tpl
    
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
  #{t(:looking_at_a_preview, :record => t('models.template', :count => 1).downcase, :scope => 'general.form.preview_top')}&nbsp;
  <% form_for([:admin, @tpl]) do %>
    <input type="hidden" name="pk" value="<%= @preview_key %>" />
    <input type="submit" name="save_and_return" value="#{t(:save_and_finish_editing, :record => t('models.template', :count => 1).downcase, :scope => 'general.form.preview_top')}" />
  <% end %>
  #{t(:or)}
  <% url = (@tpl.new_record? ? { :action => 'new' } : { :action => 'edit', :id => @tpl.id }).merge(:pk => @preview_key) %>
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

private
  def find_template(*args)
    error_key = args.pop
    other_template = args.first
    template = other_template || @journal.templates.find_by_id(params[:id])
    if template.nil?
      flash[:error] = error_key.is_a?(Symbol) ? t(error_key, :record => t('models.template', :count => 1).downcase, :scope => 'general.messages') : error_key
      redirect_to :action => 'index', :type => flash[:templates_type]
      return false
    end
    template
  end

  def post_save
    # TODO: remove
    if @tpl_attrs[:name].length > 40
      flash[:notice] = t(:template_name_truncated, :name => h(@tpl_attrs[:name][0..39]))
    end
    
    if @tpl.make_default?
      @journal.config.default.template = @tpl.name
      @journal.config.save
      flash[:notice] = t(:template_set_as_default, :name => h(@tpl.name))
    end
    
    message = t("template_#{params[:action]}d", :name => h(@tpl.name)) + %| <a href="#{@tpl.url}">| + t('messages.check_it_out') + '</a>'
    flash[:success] = message
    
    clear_preview_data(params[:pk])
    
    if params[:save_and_return]
      redirect_to :action => 'index', :type => flash[:templates_type]
    else
      redirect_to :action => 'edit', :id => @tpl.id
    end
  end

  def unencoded_preview_key(template)
    return "" if template.nil?
    "__#{template.id || Time.now.to_i}__"
  end

  # before filter
  def restrict_type
    if params[:type]
      if params[:action] == 'index' and params[:type] =~ /^\d+$/
        redirect_to :action => 'index', :type => nil, :page => params[:type]
      elsif params[:type] !~ /^(all|[cp])$/i
        redirect_to :action => 'index', :type => nil
      end
    end
  end

  # before filter
  def propagate_pagination_vars
    flash.keep(:templates_page)
    flash.keep(:templates_type)
  end
  
  def hide_global_messages
    # do not output messages in the application layout so that we can put them where we want
    @hide_global_messages = true
  end
  
end
