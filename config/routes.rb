ActionController::Routing::Routes.draw do |map|
  # user journal subdomains
  # In order for subdomains to work, a wildcard DNS has to be set up
  # Also, a RedirectRule is set up in the virtual host setup to map /~username to a subdomain
  map.with_options :name_prefix => 'journal_', :controller => 'journal', :conditions => { :subdomain => /#{User::USERNAME_PATTERN}/ } do |journal|
    journal.home "", :action => 'show_post'
    journal.main_feed "feed.atom/:key", :action => "main_feed", :defaults => { :key => nil }

    journal.with_options :action => 'show_post', :requirements => { :year => /\d{2}|\d{4}/, :month => /\d{1,2}/, :day => /\d{1,2}/ } do |post|
      post.dated_archive 'archive/:year/:month/:day', :type => "a", :month => nil, :day => nil
      post.archive ':year/:month/:day', :type => "a", :day => nil
      post.entry ':year/:month/:day/:permaname.:format', :type => "e"
    end
    journal.page ':permaname.:format', :action => 'show_post', :type => "p" 
    
    journal.category 'category/*full_slug', :action => 'show_category'
    journal.tag 'tag/*name', :action => 'show_tag'

    # Fallback route to prevent routing errors
    journal.connect ':controller/:action'
    journal.connect ':permaname', :action => 'show_post', :type => "p", :permaname => /.*/
  end

  # home
  map.home "", :controller => 'main'
  
  # main stuff
  for action in %w(prerelease tos privacy closed blackout)
    map.send(action, action, :controller => 'main', :action => action)
  end
  
  # signup
  map.connect "signup/:action", :controller => 'user/signup'
  # verify
  map.connect "verify", :controller => 'user', :action => 'verify'
  map.connect "verify/:key", :controller => 'user', :action => 'verify'
  # reset password
  map.connect "reset_password", :controller => 'user', :action => 'reset_password'
  map.connect "reset_password/:key", :controller => 'user', :action => 'reset_password'
  
  # members directory
  map.birthdays "members/birthdays", :controller => 'members', :action => 'birthdays'
  map.members "members/:search", :controller => 'members', :search => 'all', :page => 1
  map.members_paginated "members/:search/:page", :controller => 'members', :search => 'all', :page => 1

  # super admin stuff
  map.super_admin_home 'super_admin', :controller => 'super_admin/logged_exceptions'

  # april fools
  map.with_options :path_prefix => 'april' do |april|
    april.af2009 '2009/:action', :controller => 'april_fools_2009', :defaults => { :action => :index }
    april.af2010 '2010/:action', :controller => 'april_fools_2010', :defaults => { :action => :index }
  end
  map.connect 'april/:year', :controller => 'main', :action => 'index'
  map.woc 'world_of_codexed', :controller => 'april_fools_2009' #alias
  
  # admin
  map.namespace :admin do |admin|
    admin.home '', :controller => 'main'
    admin.dashboard 'dashboard', :controller => 'main', :action => 'dashboard'

    # categories
    map.with_options :controller => "admin/categories" do |c|
      c.add_category "admin/categories/add_category", :action => 'add_category'
    end
    admin.resources :categories, :member => { :delete => :get }
    
    # posts
    map.with_options :controller => "admin/entries" do |e|
      # can't do { :member => 'preview' } because :id may be nil
      e.preview_admin_entry "admin/entries/preview/:id", :action => 'preview'
      e.quick_preview_admin_entry "admin/entries/quick_preview", :action => 'quick_preview', :method => :post
      e.admin_entries "admin/entries/:page",
        :conditions => { :method => :get },
        :requirements => { :page => /\d+/ },
        :defaults => { :page => 1 }
      e.new_admin_entry "admin/entries/new", :action => 'new', :conditions => { :method => :get }
    end
    admin.resources :entries, :except => [:index, :new], :member => { :delete => :get }
    
    map.with_options :controller => "admin/pages" do |p|
      # can't do { :member => 'preview' } because :id may be nil
      p.preview_admin_page "admin/pages/preview/:id", :action => 'preview'
      p.quick_preview_admin_page "admin/pages/quick_preview", :action => 'quick_preview', :method => :post
      p.admin_pages "admin/pages/:page",
        :conditions => { :method => :get },
        :requirements => { :page => /\d+/ },
        :defaults => { :page => 1 }
      p.new_admin_page "admin/pages/new", :action => 'new', :conditions => { :method => :get }
    end
    admin.resources :pages, :except => [:index, :new], :member => { :delete => :get }

    admin.posts "posts/:page",
      :controller => "posts",
      :type => 'a',
      :conditions => { :method => :get },
      :requirements => { :page => /\d+/ },
      :defaults => { :page => 1 }
    
    # journal
    map.with_options :controller => "admin/journal" do |j|
      j.admin_journal_import "admin/journal/import", :action => 'import'
      j.admin_journal_export "admin/journal/export", :action => 'export'
    end
    
    # templates
    map.with_options :controller => "admin/templates" do |t|
      # can't do { :member => 'preview' } because :id may be nil
      t.preview_admin_template "admin/templates/preview/:id", :action => 'preview'
      t.admin_templates "admin/templates/:type/:page",
        :conditions => { :method => :get },
        :requirements => { :type => /all|c|p/, :page => /\d+/ },
        :defaults => { :type => 'all', :page => 1 }
      t.new_from_default_admin_template "admin/templates/new_from_default", :action => "new_from_default"
    end
    admin.resources :templates, :except => :index, :member => { :delete => :get }
    
    # prefabs
    map.with_options :controller => "admin/prefabs" do |p|
      p.new_admin_prefab "admin/prefabs/new/:name", :action => 'new'
      # can't do { :member => 'preview' } because :id may be nil
      p.preview_admin_prefab "admin/prefabs/preview/:id", :action => 'preview'
    end
    admin.resources :prefabs, :except => :new, :collection => { :list => :get }, :member => { :delete => :get, :convert => :any }
    
    # archive layouts
    map.with_options :controller => "admin/archive_layouts" do |a|
      a.new_admin_archive_layout "admin/archive_layouts/:id/new", :action => 'new'
    end
    admin.resources :archive_layouts, :member => { :delete => :get }
  end
  
  # default routes
  map.connect ':controller/:action/:id'
  map.connect ':controller/:action/:id.:format'
  map.connect ':controller/:action'
  map.connect ':controller'
  
  # other stuff
  map.user_favorites_feed "favorites/feed.atom/:guid", :controller => "favorites", :action => "feed", :guid => nil

end
