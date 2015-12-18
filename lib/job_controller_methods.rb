module JobControllerMethods
  def self.included(base)
    base.helper_method :job_type, :job, :job_wrapper
  end
  
  def update_progress
    if job
      update_progress_against_worker_vars
    else
      replace_update_progress_with_error
    end
  end
  
private
  def job_type
    controller_name
  end

  def job
    @journal.send("#{job_type}_job")
  end
  
  def job_wrapper
    @journal.send(job_type)
  end

  def verify_job_exists
    unless job
      flash[:error] = t(:"#{job_type}_job_missing")
      redirect_to :controller => "/admin/journal", :action => job_type
    end
  end
  
  def update_progress_against_worker_vars
    render :update do |page|
      data = job.attributes.dup
      %w(progress_percentage subprogress_percentage overall_progress_percentage elapsed_time estimated_time).each do |method|
        data[method] = job.send(method)
      end

      # Translate job messages
      data['activity'] = I18n.t(YAML.load(data['activity']), :scope => "workers.#{job_type}") if data['activity'].is_a? String
      data['subactivity'] = I18n.t(YAML.load(data['subactivity']), YAML.load(data['subactivity_params'])) if data['subactivity'].is_a? String

      partial = case
        when ((job.failed? or job.paused?) and job_wrapper.respond_to?(:data) and job_wrapper.data.nil?) then "#{job_type}_bad_data"
        when job.failed? then "#{job_type}_error"
        when job.paused?
          case
            when job_wrapper.data[:errors_exist]    then "#{job_type}_errors_exist"
            when job_wrapper.data[:conflicts_exist] then "#{job_type}_conflicts_exist"
            else                                         "#{job_type}_paused"
          end
        when job.finished? then "#{job_type}_success"
        else nil
      end
      args = [ job_type, data ]
      args << (partial ? page.send(:render, :partial => "/admin/journal/#{partial}") : nil)
      args << page.send(:render, :partial => "time_remaining", :locals => { :job => job })
      args << t("controllers.admin.journal.update_progress.and_here_we_go")  # only used when going from pending to running but we'll pass it anyway
      page.call 'updateProgress', *args
    end
  end
  
  def replace_update_progress_with_error
    # stop the ajax plz thx
    msg = t(:"#{job_type}_job_missing")
    render :update do |page|
      page.call 'updateProgress', job_type, {}, message_div_for(:error, msg), "", ""
    end
  end
end
