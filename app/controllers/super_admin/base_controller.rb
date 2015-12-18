class SuperAdmin::BaseController < ApplicationController
  
  before_filter :ensure_user_logged_in
  
  requires_login_from :user,
    :conditions => { :admin => true },
    :cookie_path => '/super_admin'
  
protected
  def ensure_user_logged_in
    # Allow users to get the RSS feed without login if they provide the GUID of an admin
    unless request.format.rss? and User.find_by_guid(params[:guid]).andand.admin?
      attempt_login_or_goto(:controller => 'super_admin/user', :action => 'login') 
    end
  end
end
