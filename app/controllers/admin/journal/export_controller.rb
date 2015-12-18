class Admin::Journal::ExportController < Admin::BaseController
  include JobControllerMethods
  
  before_filter :set_user_and_journal
  before_filter :verify_job_exists, :except => [:run, :update_progress]
  
  def run
    @journal.export!
    redirect_to :controller => '/admin/journal', :action => 'export'
  end
  
  def download
    timestamp = @journal.export.finished_at.in_time_zone.strftime("%Y%m%d")
    send_file @journal.export.outfile, :filename => "#{current_user.username}-journal-#{timestamp}.zip"
  end
  
  def cancel
    @journal.export_job.destroy
    flash[:notice] = t(:exporting_cancelled)
    redirect_to :controller => '/admin/journal', :action => 'export'
  end

end
