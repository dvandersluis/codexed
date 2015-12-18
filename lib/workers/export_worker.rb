class ExportWorker < MonitorableJobWorker
  
  BATCH_SIZE = 100
  
  def data
    @data = File.read(@outfile) if !@data and File.exists?(@outfile)
  end
  
  def run(journal_id)
    @journal = Journal.find(journal_id)
    @outfile = @journal.export.outfile
    @tmpdir = @journal.export.tmpdir
    @root = @tmpdir / "cdx-journal"
    
    # We don't store the category IDs from the database. Instead, we relate each database ID to an
    # index that applies within the archive. This allows categories to be re-imported without having
    # to rely on them already existing.
    @category_mapping = {}
    
    # pre-create directories that will go into the zip file
    %W(#{@root} #{@root}/posts #{@root}/templates #{@root}/html).each {|dir| Dir.mkdir(dir) }
    
    new_goal!(7)
    write_categories  # 1
    write_posts       # 2
    write_templates   # 3
    write_subs        # 4
    write_options     # 5
    write_html        # 6
    write_metadata    # 7
    
    # write zip
    Dir.chdir(@tmpdir)
    cmd = [ "zip", "-r", File.basename(@outfile), File.basename(@root) ]
    system(*cmd)
    raise "Couldn't run command: #{cmd.join(" ")}" unless $?.exitstatus == 0

    # clean up
    # FileUtils.rm_rf(File.basename(@root))    
  end
  
private
  def write_categories
    new_activity!(:writing_categories)

    categories = @journal.categories
    num_categories = categories.count
    new_subgoal!(num_categories + 1)

    categories = []
    i = 0

    @journal.categories.find_each(:batch_size => BATCH_SIZE, :order => :lft) do |category|
      new_subactivity!(:writing_category_n, :n => i+1, :total => num_categories, :name => category.name)
      @category_mapping[category.id] = i

      parent_id = @category_mapping[category.parent_id] || nil 
      categories.push({ :name => category.name, :slug => category.slug, :full_slug => category.full_slug.join("/"), :privacy => category.privacy, :parent_id => parent_id })

      i += 1
      advance_subprogress!
    end
    
    new_subactivity!(:writing_category_index)
    File.open(@root / "categories.yml", "w") { |f| f.write(categories.to_yaml) }
    advance_subprogress!

    advance_progress!
  end

  def write_posts
    new_activity!(:writing_posts)
    
    posts = @journal.posts
    num_posts = posts.count
    new_subgoal!(num_posts + 1)
    
    dir = @root / "posts"
    index = {}
    i = 0
    posts.find_each(:batch_size => BATCH_SIZE, :include => :template) do |entry|
      new_subactivity!(:writing_post_n, :n => i+1, :total => num_posts, :title => entry.title)
      
      index[entry.filename] = {
        :type_id => entry.type_id,
        :title => entry.title,
        :permaname => entry.permaname,
        :created_at => entry.created_at.utc,
        :updated_at => entry.updated_at.utc,
        :posted_at => entry.posted_at.utc.to_s, # Need to export as a string to avoid YAML time out of range errors
        :privacy => entry.privacy,
        :template_name => entry.assigned_template.andand.name,
        :category_ids => entry.category_ids.map { |c| @category_mapping[c] },
        :tag_names => entry.tag_names
      }
      
      content = ""
      content << "#%s\r\n" % ['-'*69]
      content << "# %-15s %s\r\n" % [ "Title:", entry.title ]
      content << "# %-15s %s\r\n" % [ "Posted:", entry.posted_at.utc.to_s(:rfc822) ]
      content << "# %-15s %s\r\n" % [ "Created:", entry.created_at.utc.to_s(:rfc822) ]
      content << "# %-15s %s\r\n" % [ "Last Updated:", entry.updated_at.utc.to_s(:rfc822) ]
      content << "#%s\r\n" % ['-'*69]
      content << "\r\n"
      content << entry.raw_body
      
      type_dir = dir / (entry.entry? ? 'entries' : 'pages')
      FileUtils.mkdir_p(type_dir)
      File.open(type_dir / entry.filename+".txt", "w") {|f| f.write(content) }
      
      advance_subprogress!
      i += 1
    end
    
    new_subactivity!(:writing_post_index)
    File.open(dir / "index.yml", "w") {|f| f.write(index.to_yaml) }
    advance_subprogress!
    
    advance_progress!
  end

  def write_templates
    new_activity!(:writing_templates)
    
    templates = @journal.templates
    num_templates = templates.count
    new_subgoal!(num_templates + 1)
    
    dir = @root / "templates"
    index = {}
    i = 0
    templates.find_each(:batch_size => BATCH_SIZE) do |template|
      new_subactivity!(:writing_template_n, :n => i+1, :total => num_templates, :name => template.name)
      
      index[template.name] = {
        :name => template.name,
        :created_at => template.created_at.utc,
        :updated_at => template.updated_at.utc
      }
      
      content = ""
      content << "#%s\r\n" % ['-'*69]
      content << "# %-15s %s\r\n" % [ "Name:", template.name ]
      content << "# %-15s %s\r\n" % [ "Created:", template.created_at.utc.to_s(:rfc822) ]
      content << "# %-15s %s\r\n" % [ "Last Updated:", template.updated_at.utc.to_s(:rfc822) ]
      content << "#%s\r\n" % ['-'*69]
      content << "\r\n"
      content << template.raw_content

      File.open(dir / template.name+".txt", "w") {|f| f.write(content) }
      
      advance_subprogress!
      i += 1
    end
    
    new_subactivity!(:writing_template_index)
    File.open(dir / "index.yml", "w") {|f| f.write(index.to_yaml) }
    advance_subprogress!
    
    advance_progress!
  end

  def write_subs
    new_activity!(:writing_subs)
    
    subs = @journal.subs
    num_subs = subs.count
    new_subgoal!(num_subs + 1)
    
    subs = {}
    i = 0
    @journal.subs.find_each(:batch_size => BATCH_SIZE) do |sub|
      new_subactivity!(:writing_sub_n, :n => i+1, :total => num_subs, :name => sub.name)
      subs[sub.name] = sub.value
      i += 1
      advance_subprogress!
    end
    
    new_subactivity!(:writing_sub_index)
    File.open(@root / "subs.yml", "w") {|f| f.write(subs.to_yaml) }
    advance_subprogress!
    
    advance_progress!
  end

  def write_options
    new_activity!(:writing_options)
    File.open(@root / "options.yml", "w") {|f| options = File.read(@journal.config.filepath); f.write(options) }
    advance_progress!
  end

  def write_html
    new_activity!(:writing_html)
    
    posts = @journal.posts
    num_posts = posts.count
    new_subgoal!(num_posts + 3)
    
    # redefine Journal#home_url and Entry#url just for this request
    Thread.current['alt_entry_url_method'] = Proc.new { |entry| "#{entry.filename}.html" }
    Thread.current['alt_journal_url_method'] = Proc.new { |journal| "index.html" }
    Thread.current['alt_category_url_method'] = Proc.new { |category| "categories/#{category.full_slug}.html" }
    Thread.current['alt_tag_url_method'] = Proc.new { |tag| "tags/#{tag.name}.html".gsub('%2F', '/') }
    dir = @root / 'html'
    FileUtils.mkdir_p(dir)
    i = 0
    posts.find_each(:batch_size => BATCH_SIZE, :include => :template) do |entry|
      new_subactivity!(:writing_html_for_post, :n => i+1, :total => num_posts, :title => entry.title)
      time = entry.posted_at
      File.open("#{dir}/#{entry.filename}.html", "w") {|f| f.write(entry.render) }
      i += 1
      advance_subprogress!
    end
    
    new_subactivity!(:writing_html_index)
    File.open("#{dir}/index.html", "w") do |f|
      index_entry = @journal.entries.empty? ? @journal.posts.find_fake_by_name("new_journal") : @journal.start_page(true)
      f.write(index_entry.render)
    end
    advance_subprogress!
    
    %w(archive split).each do |name|
      new_subactivity!(:writing_html_for_name, :name => name)
      File.open("#{dir}/#{name}.html", "w") {|f| f.write @journal.posts.find_fake_by_name(name).render }
      advance_subprogress!
    end
    
    advance_progress!
  end

  def write_metadata
    new_activity!(:writing_metadata)
   
    metadata = {
      :format => "1.2"
    }.to_yaml
    File.open(@root / ".metadata", "w") {|f| f.write metadata }
    
    advance_progress!
  end
end
