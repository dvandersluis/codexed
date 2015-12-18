class Admin::TagsController < Admin::BaseController
  def list
    redirect_to :controller => 'admin/main', :action => 'index' and return if !request.xhr?
    render :json => Tag.popular_tags.map{|name| {:value => name, :caption => name}}
  end
end
