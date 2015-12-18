# Filters added to this controller apply to all controllers in the application.
# Likewise, all the methods added will be available for all controllers.

class ApplicationController < ActionController::Base
  helper :all # include all helpers, all the time

  # See ActionController::RequestForgeryProtection for details
  # Uncomment the :secret if you're not using the cookie session store
  protect_from_forgery# :secret => '2af94aa0ffe094ca6f7cce887bedcb67'
  
  unless $FOCUSED_TEST
    before_filter :set_locale
    before_filter :set_local_timezone
    before_filter :set_base_domain
    before_filter :set_hide_sidebar
    before_filter :close_codexed
    before_filter :sopa_blackout

    include ExceptionLoggable
  
    # this adds methods like logged_in? but doesn't actually force user to login
    # if they're not logged in -- that's done in Admin::BaseController
    requires_login_from :user,
      :prefix => (Codexed.config.cookies.domain.is_a?(String) ? Codexed.config.cookies.domain.gsub(/^\.|\.$/, "").split('.')[0..1].join("_") : 'application'),
      :domain => (Codexed.config.cookies.domain || nil)
    
    def redirect_back_or_to(options = {})
      if request.env["HTTP_REFERER"].blank? 
        redirect_to options
      else
        redirect_to :back
      end
    end

  protected
    include UrlHelpersMixin
    
  private
    def set_hide_sidebar
      @hide_sidebar = (!logged_in? or controller_path =~ /super_admin/)
    end

    def set_locale
      if logged_in?
        if params[:lang] and params[:controller] != "members"
          locale = params[:lang]
        else
          locale = current_user.journal.config.lang
        end

      else
        locale = params[:lang] || cookies[:lang] || nil
        locale = :en if !locale.nil? and !I18n.valid_locale?(locale)
        unless locale.nil? or locale.blank?
          unless params[:controller] == "members"
            cookies[:lang] = {
              :path => '/',
              :value => locale.to_s, 
              :expires => 2.weeks.from_now
            }
          end
        end
      end
      
      I18n.locale = locale if !locale.nil? and I18n.valid_locale?(locale)
    end
  
    def set_base_domain
      Codexed.base_domain = SubdomainFu.host_without_subdomain(request.host)
    end
    
    def set_local_timezone
      Time.zone = current_user.journal.config.time.zone if current_user
    end

    def close_codexed
      return if current_user and current_user.admin?
      redirect_to :controller => '/main', :action => 'closed' if Codexed.closed?
    end

    def sopa_blackout
      redirect_to blackout_url(:subdomain => :www) if Time.now.in_time_zone(-5).to_date == Date.new(2012, 01, 18)
    end
  end
end
