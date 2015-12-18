class SuperAdmin::UserController < SuperAdmin::BaseController
  
  skip_before_filter :ensure_user_logged_in, :only => :login
  
  def login
    if logged_in?
      redirect_to_back_or(:controller => 'main', :action => 'index')
      return
    end
    if request.post?
      if user = User.authenticate(params[:user][:username], params[:user][:password])
        remember_login(user)
        redirect_to_back_or(:controller => 'main', :action => 'index')
        return
      else
        flash[:error] = "Invalid username or password."
      end
    end
    render :action => 'login', :layout => 'login'
  end
  
end