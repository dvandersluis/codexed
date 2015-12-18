class Admin::PostsController < Admin::BaseController
  
  # TODO: Further DRY up 'create' and 'update'
  
  before_filter :set_user_and_journal
  before_filter :ensure_correct_controller
  before_filter :set_type

  cache_sweeper :post_sweeper

  def show
    redirect_to :controller => controller_from_type(session[:posts_type]), :action => :index
  end
  
  def index
    @selectable_views = [
      [t(:all_posts)           , 'posts'],
      [t('models.entry.other') , 'entries'],
      [t('models.page.other')  , 'pages']
    ]
    @page = params[:page] || session[:posts_page] || 1

    # If per_page was changed, save it in the user's config
    # TODO: This should be in a separate action
    if params[:per_page] and params[:per_page] =~ /^[1-9]\d*$/
      @journal.config.ui.pagination.entry = params[:per_page]
      @journal.config.save
    end
    
    @per_page = @journal.config.ui.pagination.entry
    redirect_to(:action => 'index') and return if @page.to_i < 1

    session[:posts_type] = @type
    session[:posts_page] = @page

    @paginate_opts = {:page => @page, :per_page => @per_page, :order => 'posted_at DESC'}

    @posts = @journal.send(@type).paginate(@paginate_opts)

    if @posts.total_entries > 0 && @posts.out_of_bounds?
      redirect_to :action => 'index', :page => 1
      return
    end
    
    hide_global_messages
    render :template => '/admin/posts/index'
  end

  def new
    if flash[:post]
      # oops, must have had an error while saving
      @post = flash[:post]
    else
      @post = @journal.send(@type).build
      @post.use_server_time = true
      @post.privacy = @journal.config.privacy.default_entry_privacy

      if pk = params[:pk] and pd = preview_data(pk)
        @post.attributes = pd
        @post.update_tags
      end
    end

    setup_post_form

    @title = t("create_entry.#{@type.singularize}")
    render :template => '/admin/posts/form'
  end

  def create
    cancel_post(params[:pk]) and return if params[:cancel]
    
    @post_attrs = params[:post] || preview_data(params[:pk])

    if @post_attrs.nil?
      flash[:error] = t('messages.invalid_create', :record => t('models.post', :count => 1).downcase)
      redirect_to :action => :index and return
    end

    @post = @journal.send(@type).build(@post_attrs)
    @post.generate_permaname(true) if @post.entry? and @post.autoupdate_permaname?
    
    preview_post and return if params[:preview]

    save_post
  end
  
  def edit
    if flash[:post]
      # oops, must have had an error while saving
      @post = flash[:post]
    else
      @post = find_post(:missing_record_to_edit) or return
      if pk = params[:pk] and pd = preview_data(pk)
        @post.attributes = pd
        @post.update_tags
      end
    end
    
    setup_post_form

    @title = t(:editing_entry, :type => t("models.#{@type.singularize}.one").downcase)
    render :template => '/admin/posts/form'
  end

  def update
    @post = find_post(:missing_record_to_update) or return
    
    cancel_post(params[:pk]) and return if params[:cancel]

    @post_attrs = params[:post] || preview_data(params[:pk])
    @post.attributes = @post_attrs
    @post.generate_permaname(true) if @post.entry? and @post.autoupdate_permaname?
    
    preview_post(true) and return if params[:preview]

    save_post(true)
  end
  
  def delete
    @post = find_post(:missing_record_to_delete) or return
    render :template => '/admin/posts/delete'
  end
  
  # we don't technically need instance variables here but they come in handy when testing
  def destroy
    @post = find_post(:missing_record_to_delete) or return
    
    title = @post.title.length > 45 ? @post.title[0..44] + "..." : @post.title
    @post.destroy
    
    message = t(:entry_destroyed, :type => t("models.#{@post.full_type}", :count => 1), :title => h(title)).strip
    flash[:success] = message[0].chr.upcase + message[1..-1]
    redirect_to :action => 'index'
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
    
    @post = @journal.send(@type).find_by_id(params[:id]) || @journal.send(@type).build
    @post.attributes = pd 
    @post.update_tags
    template = @post.template
    
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
    @save_form_options = { :html => { :id => 'entry_form' } }
    if @post.new_record?
      @save_form_options[:url] = { :action => 'create' }
      @save_form_options[:html][:method] = 'post'
    else
      @save_form_options[:url] = { :action => 'update', :id => @post.id }
      @save_form_options[:html][:method] = 'put'
    end
    @preview_key = params[:pk]
    topbar_div = render_to_string(:inline => %|
<div id="cdx__topbar__">
  #{t(:looking_at_a_preview, :record => t("models.#{@type.singularize}.one").downcase, :scope => 'general.form.preview_top')}&nbsp;
  <% form_for(:entry, @save_form_options) do %>
    <input type="hidden" name="pk" value="<%= @preview_key %>" />
    <input type="submit" name="save_and_return" value="#{t('form.preview_top.save_and_finish_editing', :record => t("models.#{@type.singularize}.one").downcase)}" />
  <% end %>
  #{t(:or)}
  <% url = (@post.new_record? ? { :action => 'new' } : { :action => 'edit', :id => @post.id }).merge(:pk => @preview_key) %>
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
    
    # technically we don't need the render_with_template here but it helps readability
    # ironically, this comment probably doesn't ;)
    render :text => @post.render_with_template(template, current_user)
  end
  
  def quick_preview
    # These are bits and pieces from 'create' and 'update'.
    # We probably need to abstract this at some point
    post_attrs = params[:post]
    post = @journal.send(@type).build(post_attrs)
    post.generate_permaname(true) if post.entry? and post.autoupdate_permaname?
    post.put_together_posted_at!
    post.build_tags
    
    render :update do |page|
      page.replace_html 'entry_preview', post.render_without_template
      page << "var p = $('preview_area')"
      page << "if (p.style.display == 'none') p.blindDown({ duration: 0.15, afterFinish: function(effect) { effect.element.scrollIntoView() } });"
    end
  end

private
  # before filter
  def ensure_correct_controller
    # This is just here for backward compatibility with the :type parameter even though it's deprecated
    if params[:type] and controller_name = controller_from_type(params[:type]) and self.controller_name != controller_name
      logger.info "** Redirecting to :controller => #{controller_name} instead of :type => #{params[:type]}"
      redirect_to :controller => controller_name, :action => self.action_name, :type => nil
    end
  end
  
  # before filter
  def set_type
    @type = controller_name
  end

  def find_post(*args)
    error_key = args.pop
    other_post = args.first
    post = other_post || @journal.send(@type).find_by_id(params[:id])
    if post.nil?
      flash[:error] = error_key.is_a?(Symbol) ? t(error_key, :record => t("models.#{@type.singularize}.one").downcase, :scope => 'general.messages') : error_key
      redirect_to :controller => controller_from_type(session[:posts_type]), :action => 'index'
      return false
    end
    post
  end
  
  def controller_from_type(type)
    if type
      if type.length == 1
        case type.downcase
          when "e" then "entries"
          when "p" then "pages"
          else          "posts"
        end
      else
        type
      end
    else
      controller_name
    end
  end
  helper_method :controller_from_type

  # Shared between new and edit
  def setup_post_form
    @selectable_templates = [[t(:use_default_template), '']] + @journal.templates.find(:all, :order => 'name').map {|t| [t.name, t.id] }
    @date_disabled = @post.use_server_time
    @months = t('date.month_names')[1..-1].zip(("01".."12").to_a)
    if t('locale.clock_type').to_s.eql? "12"
      @hours = ["12"] + ("01".."11").to_a
      @ampm = [ [t('time.am'), "AM"], [t('time.pm'), "PM"] ]
    else
      @hours = ("00".."23").to_a
    end
    @zero_to_59 = ("00".."59").to_a
    @categories = @journal.sorted_categories
  end
  
  # Shared between create and update
  def cancel_post(pk)
    clear_preview_data(pk)
    if @post.nil?
      flash[:notice] = t(:new_entry_canceled, :type => t("models.#{@type.singularize}.one").downcase)
    else
      title = @post.title.length > 45 ? @post.title[0..44] + "..." : @post.title
      flash[:notice] = t(:changes_to_entry_not_saved, :type => t("#{@post.type_id.downcase}_desc"), :title => h(title))
    end

    redirect_to :controller => controller_from_type(session[:posts_type]), :action => 'index'
  end

  def preview_post(post_exists = false)
    @post.put_together_posted_at!
    attrs = @post_attrs.merge(@post.attributes)
    # this is ridiculous that we have to this but not sure how to get around this at the moment
    # seems to be related to storing the time object in session
    attrs["posted_at"] = attrs["posted_at"].utc unless attrs["posted_at"].nil?

    pk = set_preview_data(attrs, @post)

    redirection_attrs = {:action => 'preview', :pk => pk}
    redirection_attrs[:id] = @post if post_exists
    redirect_to redirection_attrs
  end

  def save_post(post_exists = false)
    if @post.save
      title = @post.title.length > 45 ? @post.title[0..44] + "..." : @post.title
      message_str = post_exists ? :entry_updated : :entry_created
      message = t(message_str, :type => t("models.#{@type.singularize}.one").downcase, :title => h(title)).strip +
                %| <a href="#{@post.url}">| + t('messages.check_it_out') + '</a>'
      flash[:success] = message[0].chr.upcase + message[1..-1]

      notice = []
      if @post.privacy == 'P' and @journal.crypted_entries_password.nil?
        notice << t(:password_missing_warning,
          :options_link => '<a href="' + url_for({:controller => 'admin/options', :action => 'journal'}) + '">' + t(:journal_options) + '</a>')
      end
      if @post.page? && @post.raw_body =~ /\[entrylist/
        notice << t(:page_as_archive_warning, :url => admin_archive_layouts_path)
      end
      if @post.permaname_conflict_fixed?
        notice << t(:permaname_conflict, :permaname => @post.permaname)
      end
      flash[:notice] = notice.join unless notice.empty?

      clear_preview_data(params[:pk])

      if params[:save_and_return]
        redirect_to :controller => controller_from_type(session[:posts_type]), :action => 'index'
      else
        redirect_to :action => 'edit', :id => @post.id
      end
    else
      flash[:post] = @post
      redirect_to post_exists ? { :action => 'edit', :id => @post } : { :action => 'new' }
    end
  end

  def unencoded_preview_key(post)
    return "" if post.nil?
    "__#{post.type_id}_#{post.id || Time.now.to_i}__"
  end

  def hide_global_messages
    # do not output messages in the application layout so that we can put them where we want
    @hide_global_messages = true
  end
  
end
