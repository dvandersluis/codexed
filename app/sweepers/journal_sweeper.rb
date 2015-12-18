class JournalSweeper < ActionController::Caching::Sweeper
  observe Journal
  
  # Fires after options/journal
  # A little clumsy in that it'll clear the cache even if nothing is changed, but
  # for now it'll work.
  def after_options_journal
    return if !request.post?

    journal = controller.instance_variable_get('@journal')

    # Clear the whole journal cache if the journal options are changed 
    cache_dir = ActionController::Base.page_cache_directory
    base_path = "/users/" + journal.user.username + "/"

    FileUtils.rm_r(Dir.glob(cache_dir + base_path + "/*")) rescue Errno::ENOENT
    RAILS_DEFAULT_LOGGER.info("Cache directory '#{base_path}' fully sweeped.")
  end

  def after_destroy(journal)
    # If a journal is deleted, destroy its entire cache
    cache_dir = ActionController::Base.page_cache_directory
    base_path = "/users/" + journal.user.username + "/"
    
    FileUtils.rm_rf(Dir.glob(cache_dir + base_path)) rescue Errno::ENOENT
    RAILS_DEFAULT_LOGGER.info("Cache directory '#{base_path}' fully sweeped.")
  end
end
