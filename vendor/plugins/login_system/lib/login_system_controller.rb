module LostInCode
  module LoginSystemController
    module MacroMethods
      #
      # Imports the login methods (logged_in?, current_user, etc.) into this controller.

      # You can specify one or more models that will participate in the login system like so:
      #
      #   requires_login_from :user, :author, :this_reader
      #
      # The symbols are converted into class names, so you could say this instead if you wanted to:
      #
      #   requires_login_from 'User', 'Author', 'ThisReader'
      #
      # You can also specify SQL conditions that will be used in the query to find the user.
      # This works just like the :conditions option to ActiveRecord::Base.find:
      #
      #   requires_login_from :user, :conditions => { :admin => true }
      #
      # In additions to the :conditions option, there's also:
      #
      #   :cookie_lasts_for => 2.weeks ...... how long the login cookie will last
      #   :cookie_path      => '/' .......... the path of the login cookie
      #
      def requires_login_from(*models)
        class_options = { :cookie_lasts_for => 2.weeks, :cookie_path => '/', :conditions => "", :domain => nil }
        options = models.last.is_a?(::Hash) ? models.pop : {}
        class_options[:login_models] = models.map {|model| model.to_s.classify }
        class_options[:prefix] = controller_name
        class_options.merge!(options)
        
        write_inheritable_hash :login_system_options, class_options
        class_inheritable_reader :login_system_options
        
        include InstanceMethods
        
        # Make #current_user and #logged_in? available as ActionView helper methods
        helper_method :current_user, :logged_in?, :redirected_to_login?
      end
    end
    
    module InstanceMethods
    protected
      # If the user is not logged in, stores the url the user was accessing
      # and redirects to the given url (preferably a login form of some kind)
      # Otherwise, simply returns. 
      def attempt_login_or_goto(url)
        return if logged_in?
        session[:orig_url] = current_page?(url) ? nil : request.request_uri 
        redirect_to(url) # abort filter chain
      end
  
      # Redirects to the url that was stored previously, or to the given url.
      def redirect_to_back_or(default)
        redirect_to(session[:orig_url] || default)
        session[:orig_url] = nil
      end
      
      def redirected_to_login?
        !session[:orig_url].nil?
      end
  
      def logged_in?
        !current_user.nil?
      end
      
      # Retrieves the logged in user or, if the user cookie has expired
      # or the user never logged in, nil.
      def current_user
        #logger.info "Current user: #{@current_login_system_user ? @current_login_system_user.username : "(no one)"}"
        @current_login_system_user ||= begin
          user = nil
          if mnemonic = cookies[login_cookie_name]
            for model in login_system_options[:login_models]
              model = model.constantize   # this will load the class
              model.send(:with_scope, :find => { :conditions => login_system_options[:conditions] }) {
                user = model.find_by_mnemonic(mnemonic)
              }
              if user
                # update updated_at so we know when user session was last acccessed
                user.save_without_validation!
                break
              end
            end
          end
          remember_login(user) if user  # reset cookie
          user
        end
      end
      
      # Creates a cookie for the given user based off the mnemonic stored in the user record.
      # (TODO: 'base_path' option should go into setting cookie's path?)
      # If the mnemonic is already set then don't reset it if the user has been accessed
      #  within the expiration period
      def remember_login(user)
        #cookies.delete(:login_mnemonic)
        cookie_lasts_for = login_system_options[:cookie_lasts_for]
        domain = login_system_options[:domain]
        path = login_system_options[:cookie_path]
        user.set_mnemonic! unless user.mnemonic and user.updated_at >= cookie_lasts_for.ago
        cookies[login_cookie_name] = {
          :path => path,
          :domain => domain,
          :value => user.mnemonic,
          :expires => cookie_lasts_for.from_now
        }
      end
      
      # Deletes the stored cookie for the given login.
      def forget_login
        return unless logged_in?
        current_user.clear_mnemonic! if User.exists?(current_user.id)
        cookies.delete(login_cookie_name)
        @current_login_system_user = nil
      end
      
    private  
      def current_page?(options)
        options[:controller] == controller_name && options[:action] == action_name
      end
      
      def login_cookie_name
        :"#{login_system_options[:prefix]}_login_mnemonic"
      end
    end # InstanceMethods

  end
end
