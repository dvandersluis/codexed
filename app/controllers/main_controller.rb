class MainController < BaseController  
  
  skip_before_filter :close_codexed, :only => :closed
  skip_before_filter :sopa_blackout, :only => :blackout
  
  def index
    @hide_title = true
    redirect_to :controller => 'admin/main', :action => 'index' and return if !current_user.nil? and !Codexed.closed?

    render :template => 'april_fools/april_fools2011/index' and return if Codexed.april_fools?(2011)
  end
  
  def closed
    redirect_to :action => 'index' and return if !Codexed.closed?
    render :layout => 'login'
  end

  def blackout
    render :layout => false
  end

  def prerelease
  end

  def tos
  end
  
  def privacy
  end
  
end
