require 'yaml/store'

class ImportWorker < MonitorableJobWorker
  class InvalidStructureError < StandardError; end
  
  class << self
    def convert_to_utf8(str, is_nonenglish=false)
      return str if str.blank?
      encoding = get_encoding(str, is_nonenglish)
      convert_to_utf8_from(str, encoding)
    end
    def get_encoding(str, is_nonenglish=false)
      # TODO This is slower than Christmas, any way we can speed this up??
      encoding = UniversalDetector.encoding(str).upcase
      if is_nonenglish || encoding =~ /^UTF-/
        encoding
      else
        "CP1252"
      end
    end
    def convert_to_utf8_from(str, encoding)
      return str if encoding == "UTF-8"
      begin
        Iconv.conv("UTF-8", encoding, str)
      rescue Iconv::IllegalSequence
        str
      end
    end
  end
  
  def start(journal_id, options)
    @journal = Journal.find(journal_id)
    @infile = @journal.import.infile
    @outfile = @journal.import.outfile
    
    @tmpdir = @job.tmpdir / "in"
    FileUtils.rm_rf(@tmpdir)
    FileUtils.mkdir_p(@tmpdir)
    
    new_goal!(5)
    @step_offsets = [0, 0, 0, -1, 0, 0]
    
    begin
      @data = YAML::Store.new(@outfile)
      @data.transaction do
        options.each {|k,v| @data[k.to_sym] = v.to_b }
        @data[:conflicts_exist] = @data[:errors_exist] = false
        
        extract_to_tempdir        # 1
        detect_archive_structure
        index_existing_data       # 2
        index_source_data         # 3
        sort_source_data          # 4
        
        @data[:conflicts_exist] = conflicts_exist?
      end

      verify_source_data          # 5
    rescue Exception => e
      ActionMailer::Base.view_paths = (ActionView::PathSet.new << "/srv/www/test.codexed.com/src/app/views")
      JobMailer.deliver_import_failed_email(@journal.user, e, @infile) rescue nil # If the Mailer fails, ignore its exception
      raise e # Pass the exception along
    end
    
    return :paused
  end
  
  def save(journal_id, options)
    @journal = Journal.find(journal_id)
    @outfile = @journal.import.outfile
    @data = YAML::Store.new(@outfile)
    new_goal!(2)
    @data.transaction do
      # we have to run the validations twice because in the first case
      # we only care about some of the attributes
      validate_data or return :paused
      @data[:errors_exist] = import_data
    end
    
    # clean up
    @infile = @journal.import.infile
    @tmpdir = @job.tmpdir / "in"

    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@infile)
  end
  
private
  def extract_to_tempdir
    new_activity!(:extracting_to_temp_dir)
    
    puts "Changing directory to #{@tmpdir}"
    Dir.chdir(@tmpdir)
    cmd = [ "unzip", File.join("..", File.basename(@infile)) ]
    system(*cmd)
    raise "Couldn't run command: #{cmd.join(" ")}" unless $?.exitstatus == 0
    
    advance_progress!
  end

  def detect_archive_structure
    types = {
      "dx"  => %W(dx-journal/entries dx-journal/templates dx-journal/journal.conf dx-journal/journal.toc dx-journal/subst.conf),
      "cdx" => %W(cdx-journal/templates cdx-journal/html cdx-journal/options.yml cdx-journal/subs.yml)
    }
    type = format = nil
    types.each do |t, entries|
      if entries.all? {|entry| File.exists?(@tmpdir / entry) }
        type = t
        break
      end
    end

    # If it looks like a Codexed archive, try to determine the format
    if type == "cdx"
      if File.exists?(@tmpdir / "cdx-journal" / ".metadata")
        # There is a metadata file, load the format from there
        yml = File.open(@tmpdir / "cdx-journal" / ".metadata") {|f| YAML.load(f) }
        format = yml[:format] || nil
      end
      
      if format.nil?
        if File.exists?(@tmpdir / "cdx-journal" / "entries")
          # An entries directory was present in archive format 1.0
          format = "1.0"
        elsif File.exists?(@tmpdir / "cdx-journal" / "posts")
          # ... and it was replaced by a posts directory in 1.1
          format = "1.1"
        else
          # if we get to this point, we've got an invalid structure
          type = nil
        end
      end

      format = format.to_version
    end
    
    raise InvalidStructureError unless type
    @data[:archtype] = type
    @data[:format] = format
    @rootdir = @tmpdir / "#{type}-journal"
  end
  
  def index_existing_data
    new_activity!(:index_existing_data)
    @data[:existing] = {
      :templates => YAML::Omap.new,
      :posts => YAML::Omap.new,
      :subs => YAML::Omap.new
    }
    
    templates = @journal.templates
    posts = @journal.posts
    subs = @journal.subs
    
    num_templates = templates.count
    num_posts = posts.count
    num_subs = subs.count
    
    new_subgoal!(num_templates + num_posts + num_subs)
    
    i = 0
    templates.find_each(:batch_size => 100) do |t|
      new_subactivity!(:index_existing_template_n, :n => i+1, :total => num_templates, :name => t.name)
      import_key = t.name
      @data[:existing][:templates][import_key] = t.id
      advance_subprogress!
      i += 1
    end
    i = 0
    posts.find_each(:batch_size => 100) do |p|
      new_subactivity!(:index_existing_post_n, :n => i+1, :total => num_posts, :title => p.title)
      import_key = (p.type_id == "E" ? [p.type_id, p.permaname, p.posted_at.to_date.to_s(:squeezed)] : [p.type_id, p.permaname]).join("_")
      @data[:existing][:posts][import_key] = p.id
      advance_subprogress!
      i += 1
    end
    i = 0
    subs.find_each(:batch_size => 100) do |s|
      new_subactivity!(:index_existing_sub, :n => i+1, :total => num_subs, :name => s.name)
      import_key = s.name
      @data[:existing][:subs][import_key] = s.id
      advance_subprogress!
      i += 1
    end
    
    advance_progress!
  end
  
  def index_source_data
    new_activity!(:index_source_data)
    send("index_#{@data[:archtype]}_source_data")
    advance_progress!
  end
  
  def index_dx_source_data
    @data[:source] = {
      :templates => YAML::Omap.new,
      :posts => YAML::Omap.new,
      :subs => YAML::Omap.new
    }
    
    templates_dir = @rootdir / "templates" 
    templates = Dir.entries(templates_dir).reject {|x| x.starts_with?(".") }
    
    posts_dir = @rootdir / "entries"
    posts = Dir.entries(posts_dir).reject {|x| x.starts_with?(".") }
    
    subs = self.class.convert_to_utf8(File.read(@rootdir / "subst.conf"), @data[:is_nonenglish])
    
    num_templates = templates.size
    num_posts = posts.size
    num_subs = subs.split(/\n/).size
    new_subgoal!(num_templates + num_posts + num_subs)
    
    # Load templates
    templates.each_with_index do |filename, i|
      new_subactivity!(:index_source_template_n, :n => i+1, :total => num_templates, :name => filename)
      
      filename = filename.sub(/\.([^.]+)$/, '')  # ensure no extension
      #puts "Got template #{filename}"
      
      name = filename
      raw_content = self.class.convert_to_utf8(File.read(templates_dir / filename), @data[:is_nonenglish])
      
      import_key = name
      existing_id = @data[:existing][:templates][import_key]
      @data[:source][:templates][import_key] = OpenHash.new(
        :name => name,
        :raw_content => raw_content.strip, # strip is needed to resolve a YAML bug with leading newlines
        :existing_id => existing_id,
        :import => true
      )
      
      advance_subprogress!
    end
    
    # Load posts
    posts.each_with_index do |filename, i|
      new_subactivity!(:index_source_post_n, :n => i+1, :total => num_posts, :title => filename)
      
      title_from_filename = filename.sub(/\.([^.]+)$/, '')  # ensure no extension
      #logger.debug "Got post #{filename}"
      
      # Read post body
      raw_body = self.class.convert_to_utf8(File.read(posts_dir / filename), @data[:is_nonenglish])
      # Split off the metadata that appears at the end of each post
      metadata = {}
      unless tmp = raw_body.slice!(/\s*\{.+\}\s*\Z/m)
        # TODO: Catch this
        raise "Couldn't find metadata"
      end
      tmp.strip.scan(/\{(\w+)=(.+)\}/) {|k, v| metadata[k] = v }
      type_id = (metadata['type'] == "n") ? "E" : "P"
      title = metadata['title'].blank? ? title_from_filename : metadata['title']
      permaname = (type_id == "N") ? Post.generated_permaname(title) : title_from_filename
      unless metadata['datestamp'] =~ /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})$/
        # TODO: Catch this
        raise "While parsing post '#{filename}': Couldn't convert datestamp '#{metadata['datestamp']}' to time"
      end
      posted_at = Time.zone.local(*$~.captures.map(&:to_i))
      template_name = metadata['template']
      privacy = metadata['protected'] ? 'P' : 'O'
      
      # have to do this manually since we don't have a template object yet
      # XXX: we do not check for an existing post if we're importing an entry
      #     since the permaname will be automatically fixed anyway
      import_key = (type_id == "E" ? [type_id, permaname, posted_at.to_date.to_s(:squeezed)] : [type_id, permaname]).join("_")
      existing_id = @data[:existing][:posts][import_key] unless type_id == "E"
      @data[:source][:posts][import_key] = OpenHash.new(
        :type_id => type_id,
        :title => title,
        :permaname => permaname,
        :raw_body => raw_body.strip, # strip is needed to resolve a YAML bug with leading newlines
        :posted_at => posted_at.to_s, # Converted to a string because YAML won't work right with DateTime
        :privacy => privacy,
        :template_name => template_name,
        :existing_id => existing_id,
        :import => true
      )
      
      advance_subprogress!
    end
    
    # Load substitutions
    subs.each_with_index do |line, i|
      line.chomp!
      name, value = line.split("=", 2)
      
      new_subactivity!(:index_source_sub_n, :n => i+1, :total => num_posts, :name => name)
      
      import_key = name
      existing_id = @data[:existing][:subs][import_key]
      @data[:source][:subs][import_key] = OpenHash.new(
        :name => name,
        :value => value,
        :existing_id => existing_id,
        :import => true
      )
      
      advance_subprogress!
    end
  end
  
  def index_cdx_source_data
    @data[:source] = {
      :templates => YAML::Omap.new,
      :posts => YAML::Omap.new,
      :subs => YAML::Omap.new
    }
    
    templates_dir = @rootdir / "templates"
    templates = Dir.entries(templates_dir).reject {|x| x.starts_with?(".") }
    num_templates = templates.size
    
    if @data[:format] >= 1.1
      posts_dir = @rootdir / "posts"
      files = Dir[posts_dir / "entries" / "*"] + Dir[posts_dir / "pages" / "*"]
    else
      posts_dir = @rootdir / "entries"
      files = Dir[posts_dir / "normal" / "*"] + Dir[posts_dir / "special" / "*"]
    end

    index = YAML.load_file(posts_dir / "index.yml")
    num_posts = files.size
    
    subs = YAML.load_file(@rootdir / "subs.yml")
    num_subs = subs.size
    
    num_items = num_templates + num_posts + num_subs
    extra = (1/3) * num_items
    
    new_subgoal!(num_items + extra)
    
    # Load templates
    templates.each_with_index do |filename_with_ext, i|
      # skip the index file that we generated during exporting
      next if filename_with_ext == "index.yml"
      
      filename = filename_with_ext.sub(/\.([^.]+)$/, '')  # ensure no extension
      
      new_subactivity!(:index_source_template_n, :n => i+1, :total => num_templates, :name => filename)
      
      import_key = name = filename
      raw_content = File.read(templates_dir / filename_with_ext)
      raw_content.sub!(/#-+\r\n#.+\r\n#-+\r\n+/m, '') if raw_content =~ /\A#-+/  # strip off metadata
      existing_id = @data[:existing][:templates][import_key]
      @data[:source][:templates][import_key] = OpenHash.new(
        :name => name,
        :raw_content => raw_content, # strip is needed to resolve a YAML bug with leading newlines 
        :existing_id => existing_id,
        :import => true
      )
      
      advance_subprogress!
    end
    
    # Load posts
    files.each_with_index do |full_filename, i|
      filename = File.basename(full_filename).sub(/\.([^.]+)$/, '')  # ensure no extension
      
      new_subactivity!(:index_source_post_n, :n => i+1, :total => num_posts, :title => filename)
      
      raw_body = File.read(full_filename)
      raw_body.sub!(/#-+\r\n#.+\r\n#-+\r\n+/m, '') if raw_body =~ /\A#-+/  # strip off metadata
      metadata = index[filename].dup.except(:created_at, :updated_at).to_openhash
      metadata.type_id = (metadata.type_id == "N" ? "E" : "P") if %W(N S).include? metadata.type_id # map N/S to E/P
      type_id, permaname, posted_at = metadata.values_at(:type_id, :permaname, :posted_at)
      metadata.raw_body = raw_body.strip # strip is needed to resolve a YAML bug with leading newlines
      metadata.template_name = metadata.delete(:template) if metadata.include?(:template)
      metadata.import = true
      
      # have to do this manually since we don't have a template object yet
      # XXX: we do not check for an existing post if we're importing an entry
      #     since the permaname will be automatically fixed anyway
      import_key = (type_id == "E" ? [type_id, permaname, posted_at.to_date.to_s(:squeezed)] : [type_id, permaname]).join("_")
      metadata.existing_id = @data[:existing][:posts][import_key] unless type_id == "E"
      @data[:source][:posts][import_key] = metadata
      
      advance_subprogress!
    end
    
    # Load substitutions
    subs.each_with_index do |(name, value), i|
      new_subactivity!(:index_source_sub_n, :n => i+1, :total => num_subs, :name => name)
      
      import_key = name
      existing_id = @data[:existing][:subs][import_key]
      @data[:source][:subs][import_key] = OpenHash.new(
        :name => name,
        :value => value,
        :existing_id => existing_id,
        :import => true
      )
      
      advance_subprogress!
    end

    
    # Load options
    new_subactivity!(:index_source_options)
    @data[:source][:options] = { :data => YAML.load_file(@rootdir / "options.yml"), :import => true }
    advance_subprogress!
  end
  
  def sort_source_data
    new_activity!(:sort_source_data)
    new_subgoal!(3)
    
    new_subactivity!(:sorting_templates)
    @data[:source][:templates].sort! {|(k1,t1),(k2,t2)| t1.name <=> t2.name }
    advance_subprogress!
    
    new_subactivity!(:sorting_posts)
    posts = @data[:source][:posts]
    # grr this sucks
    @data[:source][:posts] = YAML::Omap.new(
      posts.select {|k1,e1| e1.type_id == "E" }.sort_by! {|k,e| [e.posted_at, e.title] } +
      posts.select {|k1,e1| e1.type_id == "P" }.sort {|(k1,e1),(k2,e2)| e1.permaname <=> e2.permaname }
    )
    advance_subprogress!
    
    new_subactivity!(:sorting_subs)
    @data[:source][:subs].sort! {|(k1,s1),(k2,s2)| s1.name <=> s2.name }
    advance_subprogress!
    
    advance_progress!
  end

  def conflicts_exist?
    [:templates, :posts, :subs].any? do |type|
      @data[:source][type].any? {|k, item| item[:existing_id] }
    end
  end

  def verify_source_data
    # Ensure that the saved YAML file is valid
    # If it isn't, an error will be thrown later on, but we do it here to ensure 
    # an email will be sent.
    new_activity!(:verify_source_data)
    YAML::load_file(@outfile)
    advance_progress!
  end
  
  #---
  
  def validate_data
    new_activity!(:validate_data)

    all_valid = building_each_item(:validating) do |item, record, extra_data|
      record.valid?
    end
    @data[:errors_exist] = !all_valid
    
    advance_progress!
    
    all_valid
  end
  
  def import_data
    import_options = ()
    
    new_activity!(:import_data)
    
    all_valid = nil
    ActiveRecord::Base.transaction do
      all_valid = building_each_item(:importing) do |item, record, extra_data|
        if Post === record and extra_data[:template_name]
          # If the template_name is nil, leave template_id nil as well
          # Also if somehow a template name is given that hasn't been created
          record.template_id = @journal.templates.find_by_name(extra_data[:template_name], :select => "id").andand.id
        end
        # every record should have passed validation,
        # so no need to store validation errors
        begin
          record.save!
          if Post === record
            # the permaname may have been adjusted to pass uniqueness validation, so store the saved one
            item.new_permaname = record.permaname
          end
          item.id = record.id
        rescue Exception => e
          item.other_errors = e.message
        end
      end
    end
    
    # Let's hope this doesn't fail...
    if @data[:archtype] == "cdx" && @data[:source][:options][:import]
      new_subactivity!(:import_options)
      @journal.config.deep_merge!(@data[:source][:options][:data])
      @journal.config.save
      advance_subprogress!
    end
    
    @data[:errors_exist] = !all_valid
    
    advance_progress!
    
    all_valid
  end
  
  def building_each_item(action, &block)
    counts = [:templates, :posts, :subs].map do |coll|
      @data[:source][coll].sum {|key, item| item[:import] ? 1 : 0 }
    end
    subgoal = counts.sum
    if action == "Importing" && @data[:archtype] == "cdx" && @data[:source][:options][:import]
      subgoal *= (4/3)
    end
    new_subgoal!(subgoal)
    
    all_valid = true
    all_valid = building_each_item_in_collection(:templates, [     :name, :title], counts[0], action, &block) && all_valid
    all_valid = building_each_item_in_collection(:posts,     [:permaname, :title], counts[1], action, &block) && all_valid
    all_valid = building_each_item_in_collection(:subs,      [     :name, :title], counts[2], action, &block) && all_valid
    all_valid
  end
  
  def building_each_item_in_collection(collection, significant_attributes, count, action, &block)
    store_only_significant_errors = (action == :importing)
    all_valid = true
    @data[:source][collection].each_with_index do |(key, item), i|
      attrs = item.dup
      attrs.delete(:errors, :other_errors)
      attrs_to_splice = [ :import, :existing_id ]
      attrs_to_splice << :template_name if collection == :posts
      extra_data = attrs.splice_named!(*attrs_to_splice)
      
      next unless extra_data[:import]
      
      new_subactivity!("#{action}_item", :item => I18n.t(collection.to_s.singularize, :count => 1, :scope => 'models').downcase, :n => i+1, :total => count, :name => attrs[:title] || attrs[:name])
      
      attrs.keys.each {|k| if k =~ /^new_(.+)$/ then attrs[$1] = attrs.delete(k) end }
      record = @journal.send(collection).build(attrs)
      
      block.call(item, record, extra_data)
      errors = record.errors.errors.symbolize_keys
      if store_only_significant_errors
        item.errors = {}
        item.other_errors = {}
        errors.each do |attr, msgs|
          (significant_attributes.include?(attr) ? item.errors : item.other_errors)[attr] = msgs
        end
      else
        item.errors = errors
      end
      all_valid &&= item.errors.blank?
      
      advance_subprogress!
    end
    all_valid
  end

end
