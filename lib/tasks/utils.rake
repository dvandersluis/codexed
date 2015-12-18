RAILS_ROOT = File.dirname(__FILE__)+'/../../'

namespace :utils do
  desc "Upgrade user config files"
  task :upgrade_config_files => :environment do
    skel_config = ConfigurationHash.new(YAML.load_file(Codexed.config.dirs.skel_dir / 'config.yml'))
    User.find_each(:batch_size => 100) do |user|
      if !File.exists?(user.userspace_dir / 'config.yml')
        puts "Skipping #{user.username}."
        next
      end

      config = user.journal.config
      
      # login_to_new_entry
      config.ui.login_to_new_entry = false unless config.ui.include?(:login_to_new_entry)
      # default entry privacy
      config.privacy.default_entry_privacy = 'O' unless config.privacy.include?(:default_entry_privacy)
      # show_dates
      config.ui.recently_updated.show_dates = (config.ui.recently_updated.show_dates == 1)
      # lockicon
      config.entrylists.lockicon = (config.entrylists.lockicon == 1)
      # remove disabled option for sidebar
      config.ui.sidebar.sections = 2 if config.ui.sidebar.sections == -1

      # Write changes
      config.replace(skel_config.deep_merge(config.to_hash))
      config.save
      puts "Upgraded config file for #{user.username}."
    end
  end
  
  desc "Removes page cache files"
  task :clear_cache do
    require 'fileutils'
    FileUtils.rm_rf(File.expand_path("#{RAILS_ROOT}/public/cache"), :verbose => true)
  end
  
  desc "Copies user entries and templates from files to the database"
  task :copy_file_data_to_db => :environment do
    ActiveRecord::Base.transaction do
      User.paginated_each(:per_page => 50, :include => [:journal, { :journal => :user }]) do |user|
        if !File.exists?(user.userspace_dir / 'config.yml')
          puts "- Skipping #{user.username}."
          next
        end

        puts "- Got user #{user.username}"
        for template in user.journal.templates
          template.raw_content = template.old_raw_content
          puts "  - Saving template #{template.name} in #{template.filepath} to db"
          template.save!
        end
        for entry in user.journal.entries
          entry.raw_body = entry.old_raw_body
          puts "  - Saving entry #{entry.permaname} in #{entry.filepath} to db"
          entry.save!
        end
      end
    end
  end

  desc "Fix the timestamps of entry files which were saved using an offset"
  task :fix_entry_file_timestamps => :environment do
    User.find(:all).each do |user|
      log = "User #{user.username}: "
      if !File.exists?(user.entries_dir)
        puts log + "no directory found."
        next
      end

      renamed_file_count = 0
      skipped_file_count = 0

      Dir.chdir(user.entries_dir)
      Time.zone = `date +%z`.chomp[0...-2].to_i

      # Since we also have a bug in which changing the permaname will not
      # remove old files, we cannot assume that there is one file per permaname
      # Instead, check the file mtime against the updated_at stamp
      user.journal.entries.find_all_by_type('n').each do |entry|
        found_match = false
        if !File.exists?(entry.filepath)
          bad_files = Dir["[0-9]**.txt"].select { |e| e.include? entry.permaname }
          bad_files.each do |bad_file|
            if File.mtime(bad_file).to_s(:std) == entry.updated_at.to_s(:std)
              File.rename(bad_file, File.basename(entry.filepath))
              renamed_file_count += 1
              found_match = true
              break
            end
          end
          skipped_file_count += 1 and puts "couldn't find match for #{entry.title}" unless found_match
        end
      end
      puts log + "fixed #{renamed_file_count} files; skipped #{skipped_file_count} files."
    end
  end

  desc "Fill the current_entry_id column"
  task :set_current_entry_id => :environment do
    Journal.all.each do |journal|
      user = journal.user
      if !(current = journal.entries.current).nil?
        journal.current_entry_id = current.id
        puts "Setting current_entry_id for #{user.username} to #{current.id}"
        journal.save!
      end
    end
  end

  desc "Fill the favorite_journals.journal_username column"
  task :set_fj_display_name => :environment do
    FavoriteJournal.all.each do |fj|
      j = Journal.find_by_id(fj.journal_id)
      if j.nil?
        fj.destroy!
        puts "Favorite journal #{fj.id} destroyed because journal_id(#{fj.journal_id}) does not exist."
        next
      end

      fj.display_name = j.user.username
      fj.save
      puts "Favorite journal #{fj.id} had display_name set to #{fj.display_name}"
    end
  end
  
  desc "Move the user data folder out of data"
  task :move_user_data => :environment do
    if File.directory? Codexed.config.dirs.data_dir / 'users'
      # Only do anything if the users directory is already empty.
      if Dir.entries(RAILS_ROOT / 'users').reject{|dir| dir =~ /^\.{1,2}$/ }.empty? 
        FileUtils.mv Dir.glob(Codexed.config.dirs.data_dir / 'users/*'), RAILS_ROOT / 'users'
        FileUtils.rmdir Codexed.config.dirs.data_dir / 'users'
        puts "Moved user data from #{Codexed.config.dirs.data_dir / 'users'} to #{RAILS_ROOT / 'users'}."
      else
        puts "Directory #{RAILS_ROOT / 'users'} is not empty; task aborted."
        exit 1
      end
    else
      puts "Directory #{Codexed.config.dirs.data_dir / 'users'} not found; task aborted."
      exit 2
    end
  end

  desc "Fix the character encoding to be proper UTF-8"
  task :fix_encoding => :environment do
    time_start = Time.now
    verbose = ENV['VERBOSE'].to_i || 0 

    whole = {:raw_body => 0, :title => 0, :template => 0, :sub => 0}
    bychar = {:raw_body => 0, :title => 0, :template => 0, :sub => 0}

    ActiveRecord::Base.transaction do
      Entry.paginated_each(:per_page => 50, :conditions => "updated_at < '2008-12-12'") do |entry|
        puts "Entry #{entry.id} --" if verbose > 1
        [:raw_body, :title].each do |type|
          w, c = reencode_object_column(entry, type, verbose)
          whole[type] += w
          bychar[type] += c
        end

        entry.save
        puts "Saving changes to entry #{entry.id}" if verbose > 0
      end

      Template.paginated_each(:per_page => 50, :conditions => "type = 'Template' AND updated_at < '2008-12-12'") do |template|
        puts "Template #{template.id} --" if verbose > 1
        w, c = reencode_object_column(template, :raw_content, verbose)
        whole[:template] += w
        bychar[:template] += c

        template.save
        puts "Saving changes to template #{template.id}" if verbose > 0
      end
 
      Sub.paginated_each(:per_page => 50) do |sub|
        puts "Sub #{sub.id} --" if verbose > 1
        w, c = reencode_object_column(sub, :value, verbose)
        whole[:sub] += w
        bychar[:sub] += c

        sub.save
        puts "Saving changes to sub #{sub.id}" if verbose > 0
      end
    end  

    puts "Operation took #{Time.now - time_start} seconds to complete."
    puts "Entries: Raw body (#{whole[:raw_body]}/#{bychar[:raw_body]}); Title (#{whole[:title]}/#{bychar[:title]})"
    puts "Templates: (#{whole[:template]}/#{bychar[:template]})"
    puts "Subs: (#{whole[:sub]}/#{bychar[:sub]})"
  end
  
  desc "Convert all subs in the database to lowercase"
  task :downcase_subs => :environment do
    ActiveRecord::Base.transaction do
      Journal.paginated_each(:per_page => 50) do |journal|
        conflicts = Sub.find_by_sql("SELECT name
          FROM subs
          WHERE journal_id = #{journal.id}
          GROUP BY LCASE(name)
          HAVING COUNT(*) > 1").map { |sub| sub.name }

        subs = journal.subs
        
        puts "Processing subs for #{journal.user.username}."

        if !conflicts.empty?
          subs.reject! {|sub| conflicts.include? sub.name.downcase }  

          conflicts.each do |conflict|
            conflicting_subs = journal.subs.find_all_by_name(conflict)
            conflicting_subs.each do |conflicting_sub|
              puts "Cannot save #{conflicting_sub.name}, there is a conflict."
            end
          end
        end

        subs.each do |sub|
          if sub.name != sub.name.downcase
            puts "#{sub.name} -> #{sub.name.downcase}" 
            sub.update_attributes({:name => sub.name.downcase})
          end
        end
      end
    end
  end

  desc "Clear template_id of posts with an invalid one"
  task :clear_invalid_templates => :environment do
    conditions = '(NOT EXISTS (SELECT 1 FROM templates WHERE id = posts.template_id) OR posts.journal_id != templates.journal_id) AND posts.template_id IS NOT NULL'
    count = 0

    ActiveRecord::Base.transaction do
      Post.find_each(:include => :template, :conditions => conditions, :batch_size => 100) do |post|
        puts "Updating post #{post.id}: changing template_id from #{post.template_id} to NULL."
        post.template = nil
        post.save!
        count += 1
      end
    end

    include ActionView::Helpers::TextHelper
    puts "#{pluralize(count, "post")} updated."
  end

end

def reencode_object_column(obj, column, verbose)
  string = obj.send(column)
  whole = 0
  bychar = 0

  begin
    new_string = Iconv.iconv('cp1252', 'utf8', string).first;
    puts "Converted #{column} whole." if verbose > 1
    whole = 1
  rescue Iconv::IllegalSequence
    new_string = ""
    string.chars.each_char do |c|
      begin
        char = Iconv.iconv('cp1252', 'utf8', c).first
      rescue Iconv::IllegalSequence
        begin 
          char = Iconv.iconv('latin1', 'utf8', c).first
        rescue Iconv::IllegalSequence
          # No conversion has worked!
          char = c
        end
      end
      new_string += char
    end
    puts "Converted #{column} character by character." if verbose > 1
    bychar = 1
  end

  obj.send("#{column}=", new_string)
  return whole, bychar
end
