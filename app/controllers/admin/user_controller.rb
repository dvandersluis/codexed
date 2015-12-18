class Admin::UserController < Admin::BaseController
  
  skip_before_filter :ensure_user_logged_in, :only => :login
  skip_before_filter :verify_authenticity_token, :only => :login

  before_filter :verify_authenticity_token_for_login, :only => :login
  
  verify :only => [:destroy, :change_password], # more?
         :method => :post, :redirect_to => '/admin'
  
  def login
    if logged_in?
      redirect_to_back_or jump_url(current_user)
      return
    end
    if request.post?
      if user = User.authenticate(params[:user][:username], params[:user][:password])
        if user.activated?
          remember_login(user)
          redirect_to_back_or jump_url(user)
          return
        else
          @error = t(:user_not_activated, :link_text => t(:resend_the_email))
        end
      else
        @error = t(:invalid_username_or_password)
      end
    end
    render :action => 'login', :layout => 'login'
  end
  
  def logout
    forget_login
    flash[:notice] = t(:logged_out)
    redirect_to :controller => '/main', :action => 'index'
  end
  
  # called in options/account
  def destroy
    user = current_user
    if params[:confirm_destroy_password]
      if user.authenticates_against?(params[:confirm_destroy_password])
        # show view
      else
        flash[:incorrect_password] = true
        redirect_to :controller => 'options', :action => 'account', :anchor => 'remove_journal'
      end
    elsif params[:confirm]
      if params[:confirm] =~ /yes/i
        user.destroy
        forget_login
        redirect_to :controller => '/user', :action => 'sayonara'
      else
        redirect_to :controller => 'admin/options', :action => 'account'
      end
    end
  end

  def add_favorite
    ret, obj = add_user_to_favorites(params[:username])
    respond_to do |format|
      format.html do
        flash[:error] = obj if !ret 
        redirect_back_or_to :controller => '/main', :action => 'index'
      end
      format.json do
        if !ret
          render :json => {:success => false, :errors => obj}.to_json
        else
          merge_action, merge_content = get_favorites_to_merge(obj.journal.id)

          render :json => {
            :success => true,
            :username => obj.journal.user.username,
            :url => "/admin/user/remove_favorite/#{obj.journal.id}",
            :id => obj.journal.id,
            :authenticity_token => form_authenticity_token,
            :age => obj.age,
            :order => obj.order,
            :merge_action => merge_action,
            :merge_content => merge_content
          }.to_json
        end
      end
    end
  end

  def remove_favorite
    @favorite = UserFavorite.find_by_user_id_and_journal_id(current_user.id, params[:id]) unless params[:id].blank?
    
    respond_to do |format|
      format.html do
        if @favorite.nil?
          flash[:error] = t(:invalid_favorite)
        else
          @favorite.destroy
        end

        redirect_back_or_to :controller => '/main', :action => 'index'
      end
      format.json do
        if @favorite.nil?
          render :json => {:success => false, :errors => t(:invalid_favorite)}.to_json
        else
          @favorite.destroy
          
          merge_action, merge_content = get_favorites_to_merge(params[:id].to_i)

          render :json => {
            :success => true,
            :id => params[:id],
            :merge_action => merge_action,
            :merge_content => merge_content
          }.to_json
        end
      end
    end
  end

  def merge_favorites
    favorites = []
    errors = []

    UserFavorite.transaction do
      params[:id].split(',').each do |user|
        ret, obj = add_user_to_favorites(user.to_i)  
        if ret
          favorites.push(obj)
        else
          errors.push(obj)
        end
      end

      # Since we're saving multiple records potentially, rollback if any save failed
      raise ActiveRecord::Rollback unless errors.empty?
    end

    respond_to do |format|
      format.html do
        flash[:error] = errors.join("<br />\n") unless errors.empty? 
        redirect_back_or_to :controller => '/main', :action => 'index'
      end
      format.json do
        logger.info 'json block?'
        if !errors.empty?
          render :json => {:success => false, :errors => errors.join("<br />\n")}.to_json
        else
          json_obj = {
            :success => true,
            :authenticity_token => form_authenticity_token,
            :favorites => favorites.collect do |f|
              {
                :username => f.journal.user.username,
                :url => "/admin/user/remove_favorite/#{f.journal.id}",
                :id => f.journal.id,
                :age => f.age,
                :order => f.order
              }
            end
          }
          render :json => json_obj.to_json
        end
      end
    end

    logger.info "merge_favorites results: "
    logger.info favorites.inspect
    logger.info errors.inspect
  end

  def dismiss_merge_message
    cookies[:dismiss_merge_notice] = { :value => '1', :expires => Time.now + 1.year }
    
    redirect_back_or_to :controller => '/main', :action => 'index'
  end

private
  def jump_url(user)
    if user.journal.config.ui.login_to_new_entry?
      new_admin_entry_path
    else
      admin_dashboard_path
    end
  end

  def add_user_to_favorites(uid)
    if uid.is_a? String
      user = User.find_by_username(uid) unless uid.blank?
    else
      user = User.find(uid) unless uid.blank?
    end
    journal = Journal.find_by_user_id(user.id) unless user.nil?

    if user.nil? or journal.nil?
      i18n_params = uid.blank? ? ['messages.no_username_given'] : (uid.is_a?(String) ? ['messages.invalid_username', {:username => uid}] : [:invalid_user_id])
      [false, t(*i18n_params)]
    else
      favorite = current_user.user_favorites.build(
        :user_id => current_user.id,
        :journal_id => journal.id
      )

      if favorite.save
        favorite.age = if journal.current_entry.nil?
          "--"
        elsif journal.current_entry.created_at.to_date == Date.today
          l(journal.current_entry.created_at, :format => :time)
        else
          l(journal.current_entry.created_at, :format => :short_word)
        end
        favorite.order = current_user.ordered_user_favorites.index(favorite)
        [true, favorite]
      else
        [false, favorite.errors.full_messages]
      end
    end
  end

  def get_favorites_to_merge(current_id)
    # Check if there are any favorites left to merge:
    cookie_favorites = cookies[:favorites].split(',').map{ |f| f.to_i }
    merge_content = nil
    merge_action = 'none'

    if cookies[:dismiss_merge_notice].nil? and cookie_favorites.include? current_id.to_i 
      db_favorites = current_user.user_favorites.select{ |fj| !fj.journal.nil? }.map{ |fj| fj.journal.id }
      favorites_to_merge = cookie_favorites - db_favorites

      if favorites_to_merge.empty?
        merge_action = 'remove'
      else
        merge_action = 'update'
        merge_content = {
          :url => "admin/user/merge_favorites/#{favorites_to_merge.join(',')}",
          :count_text => t(:favorite_journals, :scope => 'controllers.main.favorite_journals', :count => favorites_to_merge).downcase
        }
      end
    end

    return merge_action, merge_content
  end

  # Define a special authenticity token verifier for the login action so that 
  # InvalidAuthenticityToken can be caught and handled.
  def verify_authenticity_token_for_login
    begin
      verified_request? || raise(ActionController::InvalidAuthenticityToken)
    rescue ActionController::InvalidAuthenticityToken
      @error = t(:cookies_not_enabled, :scope => 'controllers.admin.user.login')
      render :action => 'login', :layout => 'login'
    end
  end
end
