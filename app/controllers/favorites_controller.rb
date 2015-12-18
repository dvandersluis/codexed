class FavoritesController < BaseController
  
  caches_page :feed
  
  # -- TODO: Move favorites stuff in UserController here later --
  
  def feed
    # Obviously, we can't require a username/password here so we can't put this in the Admin namespace
    # But we could like some level of privacy since this feed should really be visible to only the
    # user that has the favorites list, so we require a guid so the URL is non-guessable
    @user = User.find_by_guid!(params[:guid], :include => :journal) rescue (render(:nothing => true, :status => 404) and return)
    @journal = @user.journal
    @posts = @user.favorite_journal_posts.entries.not_private.all(
      :conditions => "journals.privacy = 'O'",
      :order => "posts.created_at desc",
      :limit => 20
    )
    @last_updated_time = @posts.empty? ? Time.now : @posts.first.created_at
    
    respond_to do |wants|
      wants.atom { render :layout => false }
    end
  end
  
end
