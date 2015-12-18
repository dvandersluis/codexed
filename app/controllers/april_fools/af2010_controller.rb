class AprilFools2010Controller < BaseController  
  include LostInCode::LoginSystemController::InstanceMethods

  prepend_view_path 'app/views/april_fools'

  def index
    @page_title = "Google Writer"
    render :layout => "2010"
  end

  def gotcha
    @page_title = "Gotcha!"
  end

  def release
    redirect_to :action => :gotcha and return
  end
end
