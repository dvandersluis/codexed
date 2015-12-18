class Admin::Journal::ImportController < Admin::BaseController
  include JobControllerMethods
  
  before_filter :set_user_and_journal
  before_filter :verify_job_exists, :except => [:start, :update_progress, :get_one_item, :get_two_items]
  
  def review
    @data = @journal.import.data
    
    # convenience variables
    @templates = @data[:source][:templates]
    @entries = @data[:source][:posts].select {|k,e| e[:type_id] == "E" }
    @pages = @data[:source][:posts].select {|k,e| e[:type_id] == "P" }
    @subs = @data[:source][:subs]
    @options = @data[:source][:options]
  end
  
  def get_one_item
    unless @journal.import_job
      render :text => %|<p align="center" style="font-size: 1.3em">#{t(:import_job_missing)}</p>|
      return
    end
    type = params[:type]
    value_attr = case type
      when 'posts'     then :raw_body
      when 'templates' then :raw_content
      when 'subs'      then :value
    end
    data = @journal.import.data
    items = data[:source][type.to_sym]
    @source_value = ImportWorker.convert_to_utf8(items[params[:key]][value_attr], data[:is_nonenglish])
    render :layout => false
  end
  
  def get_two_items
    unless @journal.import_job
      render :text => %|<p align="center" style="font-size: 1.3em">#{t(:import_job_missing)}</p>|
      return
    end
    type = params[:type]
    value_attr = case type
      when 'posts'     then :raw_body
      when 'templates' then :raw_content
      when 'subs'      then :value
    end
    items = @journal.import.data[:source][type.to_sym]
    @source_value = items[params[:source_key]][value_attr]
    @existing_value = type.classify.constantize.find(params[:existing_id]).send(value_attr)
    render :layout => false
  end
  
  def summary
    @data = @journal.import.data
    
    # convenience variables
    @templates = @data[:source][:templates]
    @entries = @data[:source][:posts].select {|k,e| e[:type_id] == "E" }
    @pages = @data[:source][:posts].select {|k,e| e[:type_id] == "P" }
    @subs = @data[:source][:subs]
    @options = @data[:source][:options]
    
    @entries_password_needs_setting = (
      @data[:source][:posts].any? {|k,e| e.other_errors.blank? && e.privacy == "P" } and
      @journal.crypted_entries_password.nil?
    )
  end
  
  #---
  
  def start
    file = params[:file]
    if file.blank?
      flash[:error] = t(:no_file_given)
      redirect_to :controller => '/admin/journal', :action => 'import'
      return
    end

    # Rails will give us a StringIO if the file is 10kb or less, so put it into a more physical form
    if file.kind_of? StringIO
      file = returning(Tempfile.new("upload")) {|f| begin f.write(file.read) ensure f.close end }
    end
    # Go ahead and try to open the file to see whether it's a zip
    begin
      Zip::ZipFile.open(file.path) { }
    rescue Zip::ZipError
      flash[:error] = t(:import_error_zip_error)
      redirect_to :controller => '/admin/journal', :action => 'import'
      return
    end
    
    @journal.import!(params[:options]) do
      # this will happen after the tmpdir is deleted and recreated
      FileUtils.mv(file.path, @journal.import.infile)
    end
    redirect_to :controller => '/admin/journal', :action => 'import'
  end
  
  def save
    if params[:cancel]
      cancel
      return
    end

    data = YAML::Store.new(@journal.import.outfile)
    
    data.transaction do
      [:templates, :posts, :subs].each do |type|
        type_data = data[:source][type]
        params[type].andand.each do |key, item|
          item[:import] = item[:import].to_b
          type_data[key].merge!(item)
        end
      end
      data[:source][:options][:import] = params[:import_options].to_b if params.include?(:import_options)
    end
    
    @journal.import_job.resume_at!(:save)
    redirect_to :controller => '/admin/journal', :action => 'import'
  end
  
  def restart
    @journal.import_job.restart!
    redirect_to :controller => '/admin/journal', :action => 'import'
  end
  
  def cancel
    @journal.import_job.destroy
    flash[:notice] = t(:importing_cancelled)
    redirect_to :controller => '/admin/journal', :action => 'import'
  end
  
end
