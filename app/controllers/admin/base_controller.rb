class Admin::BaseController < ApplicationController
  
  before_filter :ensure_user_logged_in
  
  window_title { I18n.t(:title, :scope => 'controllers.admin') }
  
protected
  # before filter
  def set_user_and_journal
    @user = current_user
    @journal = @user.journal
  end
 
  # before filter
  def ensure_user_logged_in
    attempt_login_or_goto(:controller => '/admin/user', :action => 'login')
  end
  
  def preview_cache
    session[:preview] ||= {}
  end
  def preview_data_for_controller
    preview_cache[controller_name] ||= {}
  end
  def preview_data(*args)
    key = args.first if args.size == 1
    @preview_data ||= preview_data_for_controller[ key || preview_key(*args) ]
  end
  def set_preview_data(attrs, *args)
    key = preview_key(*args)
    @preview_data = preview_data_for_controller[key] = attrs
    key
  end
  def clear_preview_data(key)
    preview_data_for_controller.delete(key)
  end
  def preview_key(*args)
    # unencoded_preview_key should be defined in subclasses
    base64_encode_url(unencoded_preview_key(*args))
  end
  def base64_encode_url(str)
    # this is just to get it in a format that looks random since it'll be visible in the URL
    Base64.encode64(str).tr('+/','-_').gsub(/[\n\r=]/,'')
  end
  
end
