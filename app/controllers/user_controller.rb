class UserController < BaseController
  def sayonara
  end
  
  def verify
    if @key = params[:key] and @user = User.find_by_activation_key(@key) and not @user.activation_email_sent_at.nil?
      if !@user.activated?
        @user.activate!
        remember_login(@user)
        flash[:notice] = t(:welcome_to_codexed)
        redirect_to admin_home_path
      else
        flash[:error] = t(:user_already_activated)
        redirect_to home_path
      end
    else
      # invalid key or no key supplied
      if @user
        @error = t(:error_no_email)
      elsif @key
        if request.post?
          @error = t(:error_invalid_key) 
        else
          @error = t(:error_invalid_key_long) 
        end
      end
    end
  end

  def forgot_password
    if request.post?
      if @username = params[:username] and @user = User.find_by_username(@username)
        if @user.valid?
          @user.reset_password_key = String.random(7) 
          @user.save!
          Mailer.deliver_user_forgot_password_email(@user, home_url)
        end
      else
        # username not found, pretend that it is anyways.
      end
      flash[:success] = t(:instructions_sent, :username => @username)
      redirect_to home_path
    end
  end
  
  def reset_password
    if request.post?
      @key = params[:key]
      @user = User.find_by_reset_password_key(@key)

      new_attrs = { 'password' => params[:new_password], 'password_confirmation' => params[:new_password_confirm], 'crypted_password' => '' }
      @user.attributes = @user.attributes.merge(new_attrs)
      @username = params[:username]

      if @user.username.downcase != @username.downcase
        flash[:error] = t(:username_differs)
      elsif params[:new_password].blank?
        flash[:error] = t('models.user.new_password_blank')
      elsif params[:new_password_confirm].blank?
        flash[:error] = t('models.user.confirm_password_blank')
      elsif !@user.valid?
        flash[:error] = @user.errors.full_messages.first
      else
        @user.reset_password_key = nil
        @user.reencrypt_password!
        remember_login(@user) 
        flash[:success] = t(:password_changed)
        redirect_to home_path
      end
    else
      if @key = params[:key] and @user = User.find_by_reset_password_key(@key)
        # Show reset password form
      else
        flash[:notice] = t(:key_missing)
        redirect_to home_path
      end
    end
  end
  
  def resend_activation_email
    if request.post?
      username = params[:username]
      if username.blank?
        @error = t(:no_username_given)
      elsif user = User.find_by_username(username)
        Mailer.deliver_user_activation_email(user, home_url)
        @notice = t(:email_sent, :username => username)
      else
        @error = t('messages.invalid_username', :username => username)
      end
    else
      # show view
    end
  end
  
  #----

  # Cookie based version of the same method in admin/user_controller
  def add_favorite
    user = User.find_by_username(params[:username]) unless params[:username].blank?
    journal = Journal.find_by_user_id(user.id) unless user.nil?

    if user.nil? or journal.nil?
      i18n_params = params[:username].blank? ? ['messages.no_username_given'] : ['messages.invalid_username', {:username => params[:username]}]
      errors = t(*i18n_params)

      respond_to do |format|
        format.html do
          flash[:error] = errors
          redirect_back_or_to :controller => '/main', :action => 'index'
        end
        format.json do
          render :json => {:success => false, :errors => errors}.to_json
        end
      end
    else
      # Save the favorite into a cookie. There is one cookie per browser holding all favorites.
      favorites = []
      if !cookies[:favorites].nil?
        favorites.push(*cookies[:favorites].split(',').map{ |jid| jid.to_i })
      end

      saved = true
      if favorites.include? journal.id
        saved = false
        error = t(:favorite_journal_exists, :username => user.username) 
      else
        favorites.push(journal.id) unless favorites.include? journal.id
        cookies[:favorites] = { :value => favorites.join(','), :expires => Time.now + 1.year }
        cookies.delete :dismiss_merge_notice # If the user chose to dismiss the merge notice, undismiss it as the cookie has changed
      end

      age = if journal.current_entry.nil?
        "--"
      elsif journal.current_entry.created_at.to_date == Date.today
        l(journal.current_entry.created_at, :format => :time)
      else
        l(journal.current_entry.created_at, :format => :short_word)
      end
      favorite_journals = favorites.map { |id| Journal.find(id) }
      favorite_journals = Journal.sort_journals_by_created_at(favorite_journals)
      order = favorite_journals.map{|fj| fj.id}.index(journal.id)

      respond_to do |format|
        format.html do
          flash[:error] = error unless saved
          redirect_back_or_to :controller => '/main', :action => 'index'
        end
        format.json do
          if saved
            render :json => {
              :success => true,
              :username => user.username,
              :url => "/user/remove_favorite/#{journal.id}",
              :id => journal.id,
              :authenticity_token => form_authenticity_token,
              :age => age,
              :order => order
            }.to_json
          else
            render :json => {:success => false, :errors => error}.to_json
          end
        end
      end
    end
  end

  def remove_favorite
    journal = Journal.find_by_id(params[:id]) unless params[:id].blank?
    favorites = cookies[:favorites].split(',')

    if journal.nil? or !favorites.include?(journal.id.to_s)
      respond_to do |format|
        format.html do
          flash[:error] = t(:invalid_favorite)
          redirect_back_or_to :controller => '/main', :action => 'index'
        end
        format.json { render :json => {:success => false, :errors => t(:invalid_favorite)}.to_json }
      end
    else
      favorites.delete(journal.id.to_s)
      cookies[:favorites] = { :value => favorites.join(','), :expires => Time.now + 1.year }
      cookies.delete :dismiss_merge_notice # If the user chose to dismiss the merge notice, undismiss it as the cookie has changed
      respond_to do |format|
        format.html { redirect_back_or_to :controller => '/main', :action => 'index' }
        format.json { render :json => {:success => true, :id => journal.id}.to_json }
      end
    end
  end
  
  def auto_complete_for_favorite_journal_username
    respond_to do |format|
      format.html { redirect_to :controller => 'main', :action => 'index' }

      format.js do
        return if params[:username].nil? or params[:username].blank?

        @users = 
          if current_user
            query = "SELECT u.username 
              FROM users AS u
              JOIN journals AS j
                ON j.user_id = u.id
              LEFT JOIN user_favorites AS fj
                ON fj.user_id = ?
                  AND fj.journal_id = j.id
              WHERE LOWER(u.username) LIKE ?
                AND fj.id IS NULL 
              ORDER BY username ASC"
            User.find_by_sql([ query, current_user.id, params[:username].downcase + '%' ])
          else
            favorites = cookies[:favorites].andand.split(',') || []

            conditions = [ 'LOWER(username) LIKE ?', params[:username].downcase + '%' ]
            if !favorites.empty?
              conditions[0] += ' AND id NOT IN (?)'
              conditions.push(favorites)
            end

            User.find(:all, :conditions => conditions, :order => 'username ASC', :select => 'username')
          end

        render :inline => "<%= auto_complete_result(@users, 'username') %>"
      end
    end
  end
end

