class Admin::MainController < Admin::BaseController
  
  def index
    if current_user.journal.config.ui.login_to_new_entry
      redirect_to new_admin_entry_path
    else
      redirect_to admin_dashboard_path
    end
  end

  def dashboard
    @hide_title = true
    render :template => '/april_fools/april_fools2011/dashboard' and return if Codexed.april_fools?(2011)
  end

  def dismiss_nag_notice
    notice_type = params[:notice]
    cookies[:"dismiss_#{notice_type}_nag_notice"] = { :value => '1', :expires => Time.now + 1.year }
    
    if request.env["HTTP_REFERER"].blank? 
      redirect_to :controller => '/main', :action => 'index'
    else
      redirect_to :back
    end
  end
  
end
