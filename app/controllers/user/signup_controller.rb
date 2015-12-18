class User::SignupController < BaseController
  
  before_filter :redirect_if_logged_in
  before_filter :set_user, :except => [:index]
  before_filter :hide_sidebar
  
  def index
    if request.post?
      @user = User.new(params[:user])
      @user.validate_presence_of_password_confirmation! unless @user.password.blank?
      @user.validate_invitation_code_email!

      if @user.valid?
        session[:signup_user] = @user
        redirect_to :action => 'profile'
        return
      end
    else
      @user = User.new(:invitation_code_name => params[:code])
    end
  end

  def profile
    @days = (1..31).zip(("01".."31").to_a)
    @months = t('date.month_names')[1..-1].zip(("01".."12").to_a)
    @years = ("1900"..Time.zone.now.year.to_s)
    @countries = Country.collection_for_select(Country.all.sort_by(&:ascii_name))

    if request.post?
      # if the profile info was enterred, include it
      @user.attributes = params[:user] unless params[:skip]

      if @user.valid?
        @user.save!
        Mailer.deliver_user_activation_email(@user, home_url)
        redirect_to :action => 'thanks'
        return
      end
    end
  end
  
  def thanks
    session[:signup_user] = nil
  end
  
private
  def hide_sidebar
    @hide_sidebar = true
  end

  def set_user
    @user = session[:signup_user] or (redirect_to :action => 'index' and return)
  end

  def redirect_if_logged_in
    redirect_to :controller => '/admin/main', :action => :dashboard if current_user
  end
end
