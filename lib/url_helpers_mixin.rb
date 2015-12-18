module UrlHelpersMixin
  def self.included(base)
    if base < ActionController::Base
      base.helper_method \
        :journal_url,
        :journal_post_path,
        :journal_post_url,
        :journal_complete_archive_path,
        :journal_complete_archive_url,
        :journal_category_archive_path,
        :journal_category_archive_url,
        :journal_tag_archive_path,
        :journal_tag_archive_url,
        :admin_post_path,
        :new_admin_post_path,
        :edit_admin_post_path,
        :delete_admin_post_path,
        :list_posts_path
    end
  end

  # Note: Because journal URLs are now using subdomains instead of paths, we need
  # to make a distinction between the *_url methods and the *_path methods.
  # url methods will return a full URL, including the subdomain, whereas path
  # methods need to only return only the path.
  # That means that the correct method needs to be used in the application if the
  # subdomain is needed.
  
  # Constructs a URL for a page within a user journal. The most common case this
  # helps out with is when you want to use a named route, but you don't want to
  # pass the user explicitly.
  #
  # === Examples
  #
  # You can specify the user:
  #
  #   journal_url(User.find_by_username('bob'))          #=> "http://bob.codexed.com"
  #   journal_url(:user => User.find_by_username('bob')) #=> "http://bob.codexed.com"
  #
  # Or leave it blank to use the logged in user:
  #
  #   journal_url #=> "http://elliot.codexed.com"
  #
  # You can specify a path that goes after the username prefix:
  #
  #   journal_url('/foo') #=> "http://elliot.codexed.com/foo"
  #
  # Or pass url_for-style options (just don't pass :controller, this will mess things up):
  #
  #   journal_url(:action => 'main_feed') #=> "http://elliot.codexed.com/feed.atom"
  #
  # Or you can use a named route (note that this will automatically assume a route prefix of 'journal_'):
  #
  #   journal_url(:special_entry, :permaname => 'foo') #=> "http://elliot.codexed.com/foo"
  #
  # And you can specify all three at the same time:
  #
  #   user = User.find_by_username('stephen')
  #   journal_url(user, :main_feed, :key => user.feed_key) => "http://stephen.codexed.com/feed.atom/kF992ndFAu3"
  #
  #--
  # TODO: Rename this to journal_path
  def journal_url(*args)
    user = args.shift if User === args.first
    if Hash === args.last
      args_was_hash = true
      url_for_params = args.pop
      user ||= url_for_params.delete(:user)
    else
      url_for_params = {}
    end

    user ||= current_user
    url_for_params = url_for_params.reverse_merge(:only_path => false, :subdomain => user.username) unless url_for_params.andand[:only_path] == true

    named_route_helper_or_url = args.first || (args_was_hash ? :home_path : "/")
    case named_route_helper_or_url
    when Symbol
      send("journal_#{named_route_helper_or_url}", url_for_params)
    when String
      domain = SubdomainFu.host_without_subdomain(request.host)
      "http://#{user.username}.#{domain}" + named_route_helper_or_url
    else
      url_for(url_for_params)
    end
  end
  
  def journal_post_path(post, url_options={})
    if post.is_a?(String) || post.page?
      user = post.is_a?(String) ? current_user : post.user
      permaname = post.is_a?(String) ? post : post.permaname
      url_options.merge!(:subdomain => user.username) if url_options.andand[:only_path] == false
      journal_page_path(
        url_options.reverse_merge(:permaname => permaname)
      )
    else
      year, month, day = post.posted_at.strftime("%Y-%m-%d").split("-")
      url_options.merge!(:subdomain => post.user.username) if url_options.andand[:only_path] == false
      journal_entry_path(
        url_options.reverse_merge(
          :year => year,
          :month => month,
          :day => day,
          :permaname => post.permaname
        )
      )
    end
  end
  
  def journal_post_url(post, url_options={})
    journal_post_path(post, url_options.merge(:only_path => false))
  end
  
  def journal_complete_archive_url(url_options={})
    journal_post_url("archive", url_options)
  end
  
  def journal_complete_archive_path(url_options={})
    journal_post_path("archive", url_options)
  end
  
  def journal_category_archive_url(category, url_options={})
    journal_url(:category_path, url_options.merge(:full_slug => category.full_slug))
  end
  
  def journal_category_archive_path(category, url_options={})
    journal_category_archive_url(category, url_options.merge(:only_path => true))
  end
  
  def journal_tag_archive_url(tag, url_options={})
    journal_url(:tag_path, url_options.merge(:name => tag.name)).gsub('%2F', '/')
  end
  
  def journal_tag_archive_path(tag, url_options={})
    journal_tag_archive_url(tag, url_options.merge(:only_path => true))
  end
  
  def journal_archive_url(layout_type, url_options={})
    if layout_type.id =~ /category/
      category = @journal.categories.public.first
      journal_category_archive_url(category, url_options) if category
    elsif layout_type.id =~ /tag/
      tag = @journal.tags.first
      journal_tag_archive_url(tag, url_options) if tag
    else
      journal_complete_archive_url(url_options)
    end
  end

  def journal_archive_path(layout_type, url_options={})
    journal_archive_url(layout_type, url_options.merge(:only_path => true))
  end

  def admin_post_path(post)
    if post.entry?
      admin_entry_path(:id => post.id)
    elsif post.page?
      admin_page_path(:id => post.id)
    end
  end

  def new_admin_post_path(post)
    if post.entry?
      new_admin_entry_path
    elsif post.page?
      new_admin_page_path
    end
  end

  def edit_admin_post_path(post)
    if post.entry?
      edit_admin_entry_path(:id => post.id)
    elsif post.page?
      edit_admin_page_path(:id => post.id)
    end
  end

  def delete_admin_post_path(post)
    if post.entry?
      delete_admin_entry_path(:id => post.id)
    elsif post.page?
      delete_admin_page_path(:id => post.id)
    end
  end

  # Convenience method for getting to the right list page from a type ID
  def list_posts_path(type)
    if type == "e"
      admin_entries_path
    elsif type == "p"
      admin_pages_path
    end
  end
end
