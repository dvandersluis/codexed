namespace :codexed do
  def run_task(name)
    Rake::Task[name].invoke rescue SystemExit
  end
  
  desc "Run tasks needed to upgrade Codexed to a new release."
  task :upgrade => :environment do
    versions = %w(0.9.2 0.9.3 0.9.4 0.9.5 0.9.6 0.9.7 0.9.8 0.10 0.10.1 0.10.2 0.11)
    latest = "0.11"
    separator = "=" * 40

    if !ENV["VERSIONS"].nil?
      puts "codexed:upgrade task can be run for the following versions:\n" + versions.join(", ")
      exit
    end

    version = ENV["VERSION"] || latest
    if !versions.include? version
      puts "Version '#{version}' is not specified, exiting."
      exit
    end

    puts "Upgrading Codexed to version #{version}."
    puts "Note that this task can cause unexpected situations if run for a version that is already installed or trying to upgrade to a previous version to the current one!" 
    puts separator 

    case version
      when "0.11" then
        puts "- Migrating database to latest version."
        run_task("db:migrate")
        puts separator
        
        puts "- Updating user config files."
        run_task("utils:upgrade_config_files")
        puts separator

        puts "- Updating sugoi prefabs to new version."
        run_task("prefabs:sugoi:update")
        puts separator

        puts "- Converting [entry], [page], [locked] to block commands."
        run_task("papyrus:fix_invalid_inline_subs")
        puts separator

        puts "- Clearing invalid template IDs from posts."
        run_task("utils:clear_invalid_templates")
        puts separator

      when "0.10.2", "0.10.1", "0.10" then
        # Nothing to do for this version

      when "0.9.8" then
        puts "- Migrating database to latest version."
        run_task("db:migrate")
        puts separator
        
        puts "- Updating user config files."
        run_task("utils:upgrade_config_files")
        puts separator

        puts "- Converting entry type_ids to entries and pages."
        run_task("codexed:convert_special_entries_to_pages")
        puts separator

        puts "- Clearing cache."
        run_task("utils:clear_cache")
        puts separator

      when "0.9.7" then
        # Nothing to do for this version

      when "0.9.6" then
        puts "- Converting substitution names to lower case."
        run_task("utils:downcase_subs")
        puts separator
        
      when "0.9.5" then
        # Nothing to do for this version

      when "0.9.4" then
        puts "- Migrating database to latest version."
        run_task("db:migrate")
        puts separator
        
        puts "- Updating user config files."
        run_task("utils:upgrade_config_files")
        puts separator 

      when "0.9.3" then
        puts "- Migrating database to latest version."
        run_task("db:migrate")
        puts separator
        
      when "0.9.2" then
        puts "- Migrating database to latest version."
        run_task("db:migrate")
        puts separator 

        puts "- Filling the display_name column in the favorite_journals table."
        run_task('utils:set_fj_display_name')
        puts separator 

        puts "- Moving user data from /data/users to /users."
        run_task('utils:move_user_data')
        puts separator 

        puts "- Updating user config files."
        run_task("utils:upgrade_config_files")
        puts separator 

      else
        puts "Version #{version} is not specified, exiting."
        exit
    end

    puts "Upgrade complete."
  end

  desc "Convert normal and special entries to entries and pages."
  task :convert_special_entries_to_pages => :environment do
    klass = defined?(Entry) ? Entry : Post
    normal_count = special_count = 0
    ActiveRecord::Base.transaction do
      normal_count = klass.update_all("type_id = 'E'", "type_id = 'N'")
      special_count = klass.update_all("type_id = 'P'", "type_id = 'S'")
    end
    print "\n---- Converted #{normal_count} normal entries to entries."
    print "\n---- Converted #{special_count} special entries to pages."
    puts
  end

  namespace :db do
    
    desc "Updates current env's db according to latest migrations, copies schema over to test db, and repopulates db and filesystem with test data."
    task :migrate => :environment do
      puts "---- Updating the database as per migration files ----\n"
        Rake::Task['db:migrate'].invoke
        print "\n---- Loading the #{RAILS_ENV} database with some sample data ----\n"
        Rake::Task['codexed:db:populate'].invoke
        print "\n---- Copying schema from the #{RAILS_ENV} database to the test database ----\n"
        Rake::Task['db:test:clone_structure'].invoke
        puts "Copying done."
    end
    
    namespace :migrate do
      desc "Resets current env's db according to migrations, copies schema over to test db, and repopulates db and filesystem with test data."
      task :reset => :environment do
        puts "---- Updating the database as per migration files ----\n"
        Rake::Task['db:migrate:reset'].invoke
        print "\n---- Loading the #{RAILS_ENV} database with some sample data ----\n"
        Rake::Task['codexed:db:populate'].invoke
        print "\n---- Copying schema from the #{RAILS_ENV} database to the test database ----\n"
        Rake::Task['db:test:clone_structure'].invoke
        puts "Copying done."
      end
    end
    
    desc "Loads the current env's db with some sample data. This will also write to the data directory."
    task :populate => :environment do
      ActiveRecord::Base.establish_connection(RAILS_ENV)
      
      FileUtils.rm_r(Codexed.config.dirs.data_dir, :force => true)
      puts "Removed data directory."
      
      # Empty tables
      tables = ActiveRecord::Base.connection.select_values("SHOW TABLES")
      for table in %w(users journals entries templates)
        ActiveRecord::Base.connection.execute("TRUNCATE TABLE `#{table}`")
      end
      puts "Emptied tables."
      
      add_sample_data
      puts "Added sample data to the #{RAILS_ENV} database."
    end
    
    def add_sample_data
      user = User.create!(
        :username => 'joeschmoe',
        :password => 'joeschmoe',
        :first_name => "Joseph",
        :last_name => "Schmoe",
        :email => 'joe@schmoe.com',
        :activation_key => 'jf9d93kdd9320'
      )
      template = user.journal.templates.find_by_name('main')
      user.journal.entries.create!(:title => "My first entry", :body => <<-EOT, :template => template)
This is the first entry that I ever wrote.
        
I think it's the best in the world.
      EOT
      user.journal.entries.create!(:title => "Blargh I'm an entry", :body => <<-EOT, :template => template)
Boogedy boogedy boo..
        
I'll scare your dad!!!!
      EOT
      user.journal.entries.create!(:title => "404ed: How the Great White Shark Ate the Internet", :body => <<-EOT, :template => template)
Lorem ipsum dolor sit amet, consectetuer adipiscing elit. Praesent sollicitudin varius eros. Proin a dolor ac elit iaculis vehicula. Pellentesque feugiat eros. Phasellus id tellus. Nunc varius neque vel libero. Aliquam erat volutpat. Maecenas magna elit, dictum sit amet, posuere non, egestas vel, sem.

Sed eget odio at lacus scelerisque ornare. Fusce et nulla vehicula ligula accumsan molestie. Nam ligula quam, bibendum eget, pharetra et, ultrices vel, elit. Quisque nec nibh ac lectus venenatis posuere. Vivamus vel massa. Praesent sed lacus vel felis pretium malesuada. Sed quis dolor vitae nisi vestibulum egestas. Nulla quis nunc. Nulla facilisis arcu.
      EOT
      
      user.journal.subs.create!(:name => 'michael', :value => 'jackson')
    end
    
  end
end
