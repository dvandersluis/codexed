# Note that we can't use @template, because Rails uses that internally
# So we use @tpl instead

class JournalController < BaseController

  skip_before_filter :verify_authenticity_token, :only => :show_post # Prevent InvalidAuthenticityToken exception if cookies are disabled
  skip_before_filter :sopa_blackout, :only => [:main_feed]
  before_filter :set_user_and_journal, :set_user_timezone, :only => [ :unlock, :show_post, :show_category, :show_tag, :main_feed ]

  #after_filter :cache_journal_page, :only => [:show_post, :main_feed], :if => :cache_journal_page?

  def index
    # If someone tries to browse to /journal, send them to the home page
    redirect_to home_url, :status => 301
  end
  
  def unlock
    mode = params[:mode]
    redirect_to home_url and return if !%w(post journal).include? mode
    
    password = params["#{mode}_authentication"]
    password_field = mode == "post" ? "entries_password" : "journal_password"

    if @journal.password_authenticates? password_field => password
      if !params[:set_cookie].nil?
        create_cookie(@journal.send("locked_#{mode}_cookie"), password.sha1_encrypt) unless params[:guest].to_i == 1
      end

      flash[:unlocked] = true
      flash[:guest] = false
    else
      flash[:error] = t(:incorrect_password) 
    end
    
    redirect_back_or_to @journal.home_url 
  end

  def show_post
    # Handle journal privacy
    return if handle_protected(:journal) do |action, status|
      render :action => action, :layout => 'journal', :status => status 
    end
    
    post_params = params.splice_named!(:type, :month, :day, :year, :permaname)
    @permaname = post_params[:permaname]
    @type = post_params[:type]
    @is_entry = (post_params.include?(:day) || @permaname.nil?) && @type != 'a'
    
    @post = determine_post(post_params)
    
    # Handle post privacy
    handle_protected(:post) do |action, status|
      # Use the fake entry ERB hack to replace the post body with the unlock form
      # This is done in order to preserve post links; if the post is just replaced
      # by the fake entry, prev/next links won't work
      fake_entry = @journal.posts.find_fake_by_name(action)
      @post.body = Template.run_through_erb(fake_entry.raw_body,
        'authenticity_token' => form_authenticity_token,  # Needed for the locked form to work
        'guest' => (acting_as_guest? ? 1 : 0),
        'error' => (flash[:error] || @error),
        'notice' => (flash[:notice] || @notice),
        'journal' => @journal,
        'template' => @template
      )
      @post.http_response_status = :forbidden if @post.private?
    end
    
    @tpl = determine_template(params, @post.template)
    
    # Okay, we should have everything. Render that post!
    ivars = { 'template' => @template, 'user' => @user }

    # If the post was not found, collect some data for what to show
    if @post.fake?
      case @post.permaname
        when 'post_not_found' then
          ivars['posts'] = @is_entry ? @journal.posts.find_all_similar_from_url(post_params) : []

          # Catch URLs that look like archive pages but aren't 
          if @permaname =~ /^(\d{4}|\d{2})$/
            if @journal.posts.exists? ['posted_at between ? and ?', Time.zone.local(@permaname, 1, 1), Time.zone.local(@permaname, 12, 31, 23, 59, 59)]
              ivars['archive'] = Time.local(@permaname).year
            end
          end
      end
    end

    if @type == 'a' or (@post.fake? and @post.permaname == 'archive')
      archive_info = post_params.splice_named(:year, :month, :day)

      # This is kind of hacky, but figure out if this archive is split by time
      # TODO: A better way would be to allow Papyrus to evaluate [entrylist] first,
      # although this won't exactly help for how we set the post title here
      # as it's its own separate Papyrus render.
      if archive_info.empty?
        entrylist = @post.raw_body.scan(/\[entrylist[^\]]*\]/).first

        if !entrylist.nil? and !@journal.entries.empty? and ((day = entrylist.include? "day") or (month = entrylist.include? "month") or (year = entrylist.include? "year"))
          last_entry = @journal.entries.last(:order => :posted_at).posted_at
          archive_info = {"year" => last_entry.year}
          archive_info["month"] = last_entry.month if month or day
          archive_info["day"] = last_entry.day if day
        end
      end

      @post.title = Papyrus::Template.render(@post.title,
        :custom_command_class => Template::CustomCommands,
        :extra => { :cdx_template => @tpl, :archive_info => archive_info },
        :allowed_commands => %W(archivedate)
      )
    end

    @tpl.active_post = @post
    result = @tpl.render(current_user, ivars,
      :persistent_vars => {
        :persist_template => !params[:template].nil?,
        :guest => acting_as_guest?
      },
      :privileged_reader => privileged_reader?,
      :archive_info => archive_info
    )

    render :text => result, :status => @post.http_response_status
  end
  
  def show_category
    # Handle journal privacy
    return if handle_protected(:journal) do |action, status|
      render :action => action, :layout => 'journal', :status => status
    end
    
    ivars = { 'template' => @template, 'user' => @user }

    @category = @journal.categories.find_by_full_slug(params[:full_slug])
    
    if @category and @post = @journal.archive_layouts.find_as_post('category_archive')
      @post.title = Papyrus::Template.render(@post.title,
        :custom_command_class => Template::CustomCommands,
        :vars => { "category" => h(@category.name) }
      )
      
      # Handle category privacy
      handle_protected(:category) do |action, status|
        # Use the fake entry ERB hack to replace the post body with the unlock form
        # This is done in order to preserve post links; if the post is just replaced
        # by the fake entry, prev/next links won't work
        fake_entry = @journal.posts.find_fake_by_name(action)
        @post.body = Template.run_through_erb(fake_entry.raw_body, 'template' => @template)
      end
    else
      @post = @journal.posts.find_fake_by_name('category_not_found')
      ivars['categories'] = @journal.categories
    end
    
    @tpl = determine_template(params, @post.template)
    @tpl.active_post = @post
    result = @tpl.render(current_user, ivars,
      :persistent_vars => {
        :persist_template => !params[:template].nil?
      },
      :category => @category
    )
    render :text => result, :status => @post.http_response_status
  end

  def show_tag
    # Handle journal privacy
    return if handle_protected(:journal) do |action, status|
      render :action => action, :layout => 'journal', :status => status
    end

    name = params[:name].join("/")
    name = request.path_info.gsub(%r{^.*?/tag/}, "") if name.blank?
    @tag = @journal.tags.find_by_name(name)
    
    ivars = { 'template' => @template, 'user' => @user }

    if @tag and @post = @journal.archive_layouts.find_as_post('tag_archive')
      @post.title = Papyrus::Template.render(@post.title,
        :custom_command_class => Template::CustomCommands,
        :vars => { "tag" => h(@tag.name) }
      )

      @post.body = Template.run_through_erb(@post.raw_body, 'template' => @template)
    else
      @post = @journal.posts.find_fake_by_name('tag_not_found')
    end

    @tpl = determine_template(params, @post.template)
    @tpl.active_post = @post
    result = @tpl.render(current_user, ivars,
      :persistent_vars => {
        :persist_template => !params[:template].nil?
      },
      :tag => @tag
    )
    render :text => result, :status => @post.http_response_status
  end

  def main_feed
    @key = params[:key]
    @correct_key_given = (@key && @journal.feed_key == @key)
    # Do not allow access, period, if the journal is private
    # Do not allow access without the proper key if the journal is password-protected
    if @journal.private?
      render :nothing => true, :status => :forbidden
      return
    elsif @journal.protected? && !@correct_key_given
      respond_to do |wants|
        wants.atom { render :layout => false, :action => 'locked_feed' and return }
      end
    end
    # Always show password-protected posts, but note that unless the key is given,
    #  we'll just show a placeholder body for the post
    # Private posts are always hidden
    @posts = @journal.entries.not_private.all(:order => "posted_at DESC", :limit => 20)
    @last_updated_time = @posts.empty? ? Time.now : @posts.first.created_at
    
    respond_to do |wants|
      wants.atom { render :layout => false }
    end
  end
  
private
  def viewing_as_journal_owner?
    current_user && current_user == @user
  end
  
  def viewing_as_guest?
    !viewing_as_journal_owner?
  end

  def acting_as_guest?
    params[:guest] && (flash[:guest].nil? || flash[:guest] != false)
  end
  
  def privileged_reader?
    # this is used to control whether [feed_link_tag] should have the private feed URL or public feed URL
    (viewing_as_guest? and (journal_unlocked? or post_unlocked?)) or viewing_as_journal_owner?
  end
  
  def journal_unlocked?
    (cookies[@journal.locked_journal_cookie] && cookies[@journal.locked_journal_cookie] == @journal.crypted_journal_password) || flash[:unlocked]
  end

  def post_unlocked?
    (cookies[@journal.locked_post_cookie] && cookies[@journal.locked_post_cookie] == @journal.crypted_entries_password) || flash[:unlocked]
  end
  
  def create_cookie(name, value)
    cookies[name] = {
      :value => value,
      :expires => Time.now + 1.month
    }
  end

  def refresh_cookie(name, length = 1.month)
    cookies[name] = {
      :value => cookies[name],
      :expires => Time.now + length 
    } if cookies[name] # if the cookie doesn't already exist, we don't want to create one
  end
    
  def handle_protected(type, &block)
    record = instance_variable_get("@#{type}")
    action = nil
    is_locked = record.respond_to?(:locked?) ? record.locked? : record.private?
    if is_locked and (viewing_as_guest? or acting_as_guest?)
      if record.respond_to?(:protected?) && record.protected?
        cookie_key = @journal.send("locked_#{type}_cookie")
        record_unlocked = send("#{type}_unlocked?")
        if record_unlocked
          refresh_cookie(cookie_key)
        else
          if cookies[cookie_key] && !acting_as_guest?
            @notice = t(:journal_authentication_changed)
            cookies.delete(cookie_key)
          end
          action = "#{type}_locked"
        end
      elsif record.private?
        action = "#{type}_private"
        status = :forbidden
      end
      yield action, status if action
    end
    action
  end
  
  def determine_post(post_params)
    if @journal.posts.current(viewing_as_journal_owner?).nil? and @journal.start_page.nil? and @is_entry 
      # No posts in journal! Display a "new journal" fake entry.
      post = @journal.posts.find_fake_by_name('new_journal')
    elsif post_params.empty?
      # This is the journal home - show the start page
      post = @journal.start_page(viewing_as_journal_owner?)
    else
      # Try to find the post first.
      # If that fails, but the given permaname matches a fake entry, display that.
      # And if that fails, we'll want to display an error message (but see below).
      post = @journal.posts.find_from_url(post_params)
      if !post && !@is_entry
        if %w(archive archives).include?(@permaname) or @type == 'a' 
          post = @journal.archive_layouts.find_as_post("complete_archive")
          @type = 'a'
        else
          post = @journal.posts.find_fake_by_name(@permaname)
          # Stop users from being able to directly load fake entries that are not meant to be loaded directly
          post = nil unless %w(archive lorem split category_not_found).include? post.andand.permaname
        end
      end
    end

    post || @journal.posts.find_fake_by_name('post_not_found')
  end
  
  def determine_template(params, default_template)
    # Figure out which template to use to render the post.
    # If the user passed in a template in the QS, try to find that.
    # If we couldn't find a template or no template passed, use the template assigned to the post,
    #  or the fake fallback template.
    if params[:template]
      template = @journal.templates.find_by_name(params[:template])
    elsif params[:prefab] and !Prefab.skeleton(params[:prefab]).nil?
      template = Prefab.new(:prefab_name => params[:prefab], :journal => @journal)
      if !session[:prefab].nil? and session[:prefab].is_a? Prefab and params[:use_session]
        template.config.deep_merge!(session[:prefab].config)
      end
    end
    template || default_template
  end
  
  def cache_journal_post?
    !(@journal.locked? || @post.locked? || params[:template])
  end

  def cache_main_feed?
    !@journal.locked?
  end

  def cache_journal_page?
    case action_name
      when "show_post"  then cache_journal_post?
      when "main_feed"  then cache_main_feed?
    end
  end
    
  # before filter
  def set_user_and_journal
    user = current_subdomain 
    unless @user = User.find_by_username(user)
      if params[:action] == 'main_feed'
        # Throw a 404 if asking for the feed for a non-existent journal
        render :nothing => true, :status => :not_found 
      else
        render :action => 'user_not_found', :layout => 'journal'
      end
      return false  # break filter chain
    end
    @journal = @user.journal
  end

  # before filter
  def set_user_timezone
    Time.zone = @journal.config.time.zone
  end
  
  # after filter
  def cache_journal_page
    path = "/users/#{@user.username}" + request.path.sub("/~#{@user.username}", "")
    path.chomp!("/")
    cache_page(nil, path)
  end
  
end
