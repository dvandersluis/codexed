class Admin::OptionsController < Admin::BaseController
  
  before_filter :set_user_and_journal
  before_filter :set_config
  before_filter :save_options, :only => [:main, :formatting], :if => Proc.new {|c| c.request.post? }
  before_filter :hide_global_messages
  before_filter :setup_string_collections, :only => [:account, :change_password, :update_profile, :update_user]

  cache_sweeper :journal_sweeper, :only => [:journal]
  
  title { t(:title) }

  def index
    redirect_to :action => 'main'
  end

  def main 
    @languages = Language.translations.ordered.map do |l|
      [l.localized_name || l.long_name, l.short_name]
    end
  end

  def formatting
    @archive_format_preview = get_archive_format_preview(@config.entrylists.archiveformat, @config.entrylists.lockicon)
    @year_format_preview = get_time_format_preview(@config.formatting.time.year)
    @year_month_format_preview = get_time_format_preview(@config.formatting.time.month)
    @full_format_preview = get_time_format_preview(@config.formatting.time.full)
  end
  
  def journal
    if request.post?
      if params[:reset]
        @journal.reset_attributes %w(title privacy crypted_journal_password crypted_entries_password)
        @config.reset_keys params[:config]
        message = t(:options_reset)
      elsif params[:journal]
        journal_params = params[:journal].clone

        if journal_params[:privacy] != 'P'
          journal_params[:journal_password] = nil
          @journal.crypted_journal_password = nil
        else
          # If JS is enabled, and the password is set, the password input will be set to *****... clear it if change is not checked.  
          ['journal', 'entries'].each do |type|
            journal_params["#{type}_password"] = nil if (!@journal['crypted_#{type}_password'].blank? and !params[:password_changed][type].to_b)
          end
        end

        @journal.attributes = journal_params
        @config.deep_merge!(params[:config])

        message = t(:options_saved)
      elsif !params[:regenerate_feed_key]
        # Somehow the form was posted with no relevant post data?
        redirect_to :action => 'journal'
      end

      if @journal.valid? and params[:regenerate_feed_key]
        @journal.generate_feed_key
        flash[:feeds_success] = t(:feed_key_regenerated)

        if !params[:commit]
          # we redirect here so we can set the anchor
          @journal.save
          redirect_to :action => 'journal', :anchor => 'feeds'
          return
        end
      end

      if @journal.valid?
        @journal.save
        @config.save
        @success = message 
      end
    end
  end
  
  def account
    @incorrect_password = flash[:incorrect_password]
    @days = (1..31).zip(("01".."31").to_a)
    @months = t('date.month_names')[1..-1].zip(("01".."12").to_a)
    @years = ("1900"..Time.zone.now.year.to_s)

    if request.post?
      change_password if params[:change_password]
      update_profile if params[:update_profile]
      update_user if params[:update_user]
    end
  end

  def preview_archive_format
    render :inline => get_archive_format_preview(params[:archive_format], params[:lock_icon].to_b)
  end

  def preview_time_format
    render :inline => get_time_format_preview(params[:format])
  end

private
  def change_password 
    begin
      if @user.change_password!(params[:current_password], params[:new_password], params[:new_password_confirm])
        remember_login(@user)
        @success = t(:password_changed_no_login)
      end
    rescue ArgumentError => e
      @password_error = e.message 
    end 
  end

  def update_profile
    journal_params = params[:journal].clone
    journal_params[:language_id] = nil if journal_params[:language_id].to_i == 0
    @journal.update_attributes(journal_params)

    if @journal.valid?
      @journal.save
      @success = t(:account_saved)
    end
  end

  def update_user
    user_params = params[:user].clone
    @user.update_attributes(user_params)

    if @user.valid?
      @user.save
      @success = t(:account_saved)
    end
  end
  
  def get_time_format_preview(format)
    Template::CustomCommands.new(nil).now([format])
  end

  def get_archive_format_preview(archive_format, lockicon = false)
    current_user.journal.config.entrylists.lockicon = lockicon  # this is temporary
    string = "[lastfew 3 \"#{archive_format}\"]"
    Papyrus::Template.render(string,
      :custom_command_class => Template::CustomCommands,
      :shielded_commands => %w(lastfew),
      :extra => { :current_user => current_user }
    )
  end

  # before filter
  def save_options
    if params[:reset]
      # If resetting, revert any config params that are settable on this page to the skel value
      if params[:config]
        @config.reset_keys params[:config]
        @config.save
      end

      @success = t(:options_reset)
    elsif params[:config]
      if params[:config][:formatting].andand[:time]
        time_params = params[:config][:formatting][:time]
        if time_params[:year].blank? or time_params[:month].blank? or time_params[:full].blank?
          @config.deep_merge!(params[:config])
          flash[:config] = @config
          @error = t(:time_format_cannot_be_blank)
          return false
        end
      end

      if !params[:config][:lang].nil? and @config.lang != params[:config][:lang]
        # If the language has changed, immediately set the new locale so that the strings are correct when post completes 
        I18n.locale = params[:config][:lang]
        window_titles[0] = I18n.t(:title, :scope => 'controllers.admin')
      end

      @config.deep_merge!(params[:config])
      @config.save
      @success = t(:options_saved)
    end
  end
  
  def set_config
    @config = flash[:config] || @journal.config
  end

  def hide_global_messages
    # do not output messages in the application layout so that we can put them where we want
    @hide_global_messages = true
  end
  
  def setup_string_collections
    @countries = Country.collection_for_select(Country.all.sort_by(&:ascii_name))
    @languages = Language.collection_for_select(Language.allowed_in_profile.ordered) do |lang|
      desc = Language.strings[lang.id]
      desc += " [#{lang.localized_name}]" if Language.strings[lang.id] != lang.localized_name
    end
  end
end
