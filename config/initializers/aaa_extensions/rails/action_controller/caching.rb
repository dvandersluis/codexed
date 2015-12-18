module ActionController
  module Caching
    module Pages
      module ClassMethods
        # Update expire_page and cache_page to log as info instead of debug
        def expire_page(path)
          return unless perform_caching

          benchmark "Expired page: #{page_cache_file(path)}", Logger::INFO do
            File.delete(page_cache_path(path)) if File.exist?(page_cache_path(path))
          end
        end
        
        def cache_page(content, path)
          return unless perform_caching

          benchmark "Cached page: #{page_cache_file(path)}", Logger::INFO do
            FileUtils.makedirs(File.dirname(page_cache_path(path)))
            File.open(page_cache_path(path), "wb+") { |f| f.write(content) }
          end
        end
      end
    end
  end
end
