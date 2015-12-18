class PostSweeper < ActionController::Caching::Sweeper
  observe Post
  
  def after_save(post)
    expire_cache_for(post)
  end

  def after_destroy(post)
    expire_cache_for(post)
  end

private
  def expire_cache_for(record)
    cache_dir = ActionController::Base.page_cache_directory
    base_path = "/users/" + record.user.username + "/"
    
    # Because compiled entries can contain [lastfew] or [entrylist], we need to sweep all entries
    # whenever an post is saved or destroyed
    FileUtils.rm_r(Dir.glob(cache_dir + base_path + "/*")) rescue Errno::ENOENT
    RAILS_DEFAULT_LOGGER.info("Cache directory '#{base_path}' fully sweeped.")

    # Expire the start page
    expire_page(base_path)
  end
end
