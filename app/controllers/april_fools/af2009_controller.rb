class AprilFools2009Controller < BaseController  
  prepend_view_path 'app/views/april_fools'

  def index
    @hide_title = true
  end

  def register
    @hide_title = true
  end
end
