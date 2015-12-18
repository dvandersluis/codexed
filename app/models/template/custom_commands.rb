class Template
  class CustomCommands < Papyrus::CustomCommandSet
    include I18nModelExtension
    extend I18nModelExtension
    
    ENTRY_NAMES_REGEX = /^(first|last|prev|next|curr|home|archive|split|random)$/
    ATTRS_REGEX = /^(title|url|link)$/
    
    attr_accessor :journal, :post, :guest
    
    def initialize(*_)
      super
      
      @cdx_template = @args[:cdx_template]
      @current_user = @args[:current_user]
      @current_journal = @current_user.andand.journal
      @privileged_reader = @args[:privileged_reader]
      @active_post = @args[:post]
      @category = @args[:category]
      @tag = @args[:tag]
      @archive_info = @args[:archive_info] || {}
      @archive_range = archive_range(@archive_info)
      
      persistent_vars = @args[:persistent_vars] || {}
      @persist_template = persistent_vars[:persist_template] || false
      @guest = persistent_vars[:guest] || false

      @find_post = {}
    end

    module InlineCommands
      # Syntax:
      #   time [FORMAT]
      # where:
      #   FORMAT ::= string
      def now(args)
        format_time(Time.zone.now, args)
      end

      def time(args)
        format_time(self.post.posted_at, args)
      end

      def archivedate(args)
        return "" unless @archive_range.is_a?(Array)
        formatted_archive_date
      end

      def archivenext(args)
        # Create a link for the next archive page
        return "" if @archive_info.empty?

        year, month, day = *[@archive_info["year"], @archive_info["month"] || 1, @archive_info["day"] || 1].map(&:to_i)
        return "" unless Date.valid_date? *[year, month, day]

        unit = @archive_info["day"] ? "day" : (@archive_info["month"] ? "month" : "year")
        next_entry = @journal.entries.first(:select => :posted_at, :conditions => ["posted_at >= ?", Time.zone.local(year, month, day) + 1.send(unit)], :order => "posted_at ASC")
        archive_link(next_entry, args)
      end

      def archiveprev(args)
        # Create a link for the previous archive page
        return "" if @archive_info.empty?

        year, month, day = *[@archive_info["year"], @archive_info["month"] || 1, @archive_info["day"] || 1].map(&:to_i)
        return "" unless Date.valid_date? *[year, month, day]

        previous_entry = @journal.entries.first(:select => :posted_at, :conditions => ["posted_at < ?", Time.zone.local(year, month, day)], :order => "posted_at DESC")
        archive_link(previous_entry, args)
      end
      
      # Syntax:
      #   entrylist <['descending'] ['split'] [FORMAT]>
      def entrylist(args)
        args = args.flatten
        order = extract_from_args!(args, 'descending') ? 'desc' : 'asc'
        split = extract_from_args!(args, 'split')
        year = extract_from_args!(args, 'year')
        month = extract_from_args!(args, 'month')
        day = extract_from_args!(args, 'day')

        out = Papyrus::SeparateString.new 

        if @tag.nil?
          format = args

          if @archive_range == -1
            # Trying to access the archive for an invalid date
            out << "<p>#{t(:invalid_date_for_archive)}</p>"
          else
            # note that we create scopes here - we don't do the query right away
            # this is so if we're dealing with a very large journal here we don't pull in all the posts at once
            #  but we can iterate through them in batches
            posts = journal.entries
            posts = posts.not_private unless include_private?
            posts = posts.scoped(:joins => :categories, :conditions => ["categories.id = ?", @category.id]) if @category

            # filter by date
            if !@journal.entries.blank? and (@archive_range or year or month or day)
              unless @archive_range
                last_entry = @journal.entries.last.posted_at
                @archive_info = {"year" => last_entry.year}
                @archive_info["month"] = last_entry.month if month or day
                @archive_info["day"] = last_entry.day if day
                @archive_range = archive_range(@archive_info)
              end

              posts = posts.scoped(:conditions => ["posted_at between ? and ?", *@archive_range])
            end

            if posts.empty?
              if @category
                out << "<p>#{t(:category_no_entries)}</p>"
              elsif @archive_range
                out << "<p>#{t(:journal_no_entries_for_date, :date => formatted_archive_date)}</p>";
              else
                out << "<p>#{t(:journal_no_entries)}</p>"
              end
            else
              if split
                out << handle_split(posts, format, order)
              else
                out << generate_list(posts, format, order)
              end
            end
          end
        else
          others = extract_from_args!(args, 'others')
          exists = extract_from_args!(args, 'exists')
          format = args

          posts = others ?
            @tag.posts.scoped(:conditions => ["journal_id != ? AND privacy != 'C'", journal.id], :limit => 10) :
            journal.posts.scoped(:joins => :tags, :conditions => ['tags.name = ?', @tag.name])

          return "" if posts.all.empty? and exists
          
          if exists
            out << args.to_a.join(" ")
          else
            if split
              out << handle_split(posts, format, order)
            else
              out << generate_list(posts, format, order)
            end
          end
        end

        out
      end

      # Syntax:
      #   parent <['exists'] ['list'] [...]>
      def parent(args)
        return "" if @category.nil? # This sub is only relevant when we're dealing with a category

        exists = extract_from_args!(args, 'exists')
        parent = @category.parent
        return "" if exists and parent.nil?

        list = extract_from_args!(args, 'list')
        if !args.empty?
          args.join(" ")
        else
          list_categories(parent, "categorylist", list)
        end
      end
      
      # Syntax:
      #   parents <['exists'] ['list'] [...]>
      def parents(args)
        return "" if @category.nil? # This sub is only relevant when we're dealing with a category

        exists = extract_from_args!(args, 'exists')
        parents = @category.ancestors
        return "" if exists and (parents.nil? or parents.empty?)

        list = extract_from_args!(args, 'list')
        if !args.empty?
          args.join(" ")
        else
          list_categories(parents, "categorylist", list)
        end
      end

      # Syntax:
      #   children <['exists'] ['list'] [...]>
      def children(args)
        return "" if @category.nil? # This sub is only relevant when we're dealing with a category

        exists = extract_from_args!(args, 'exists')
        children = @category.children
        return "" if exists and (children.nil? or children.empty?)
        
        list = extract_from_args!(args, 'list')
        if !args.empty?
          args.join(" ")
        else
          list_categories(children, "categorylist", list)
        end
      end

      # Syntax:
      #   categories <['exists'] ['list'] [...]>
      def categories(args)
        exists = extract_from_args!(args, /^exists?$/)
        
        categories = self.post.categories
        categories.reject! {|category| category.private?} unless include_private?
        return "" if exists and categories.empty?

        list = extract_from_args!(args, 'list')
        if !args.empty?
          args.join(" ")
        else
          list_categories(categories.sort_by(&:name), "categorylist", list)
        end
      end

      def categorylist(args)
        exists = extract_from_args!(args, /^exists?$/)
        used = extract_from_args!(args, 'used')
        children = extract_from_args!(args, 'children')
        counts = extract_from_args!(args, 'counts') || extract_from_args!(args, 'count')

        # Should children categories be included?
        if children
          categories = []
          self.journal.sorted_categories.each do |category|
            categories.push *category.self_and_descendants.sort_by(&:lft) 
          end
        else
          categories = self.journal.sorted_categories
        end

        categories.reject! {|category| category.private?} unless include_private?
          
        categories.reject! {|category| category.post_categories.count == 0 } if used

        return "" if exists and categories.empty?

        if !args.empty?
          args.join(" ")
        else
          list_categories(categories, "allcategories", true, counts)
        end
      end

      # Syntax:
      #   tags <['exists'] ['list'] [...]>
      def tags(args)
        exists = extract_from_args!(args, /^exists?$/)
        
        tags = self.post.tags
        return "" if exists and tags.empty?
        
        list = extract_from_args!(args, 'list')
        if !args.empty?
          args.join(" ")
        else
          list_categories(tags.sort_by(&:name), "taglist", list)
        end
      end
      
      # Syntax:
      #   lastfew <[COUNT] [FORMAT] ['reverse']>
      # where:
      #   COUNT  ::= number
      #   FORMAT ::= string
      def lastfew(args)
        args = args.flatten
        count, format = nil

        if !args.empty? 
          reverse = extract_from_args!(args, 'reverse')
          count = extract_from_args!(args, /^\d+$/).to_i
          format = args
        end

        count = 10 if count == 0 or count.nil?

        conditions = "posts.privacy != 'C'" unless include_private?
        posts = journal.entries.scoped(:conditions => conditions)
        out = generate_list(posts, format, (reverse ? "asc" : "desc"), count)
        Papyrus::SeparateString.new(out)
      end
      
      # Syntax:
      #   lock_icon [SIZE]
      # where:
      #   SIZE  ::= number
      def lock_icon(args)
        size = args.first.to_i || nil
        size = nil if size == 16 # 16px is the default version 

        image_name = "lock#{size.to_s}.png"
        image_name = "lock.png" if !File.exists? RAILS_ROOT / 'public' / 'images' / 'icons' / image_name 

        %|<img class="lockicon" src="/images/icons/#{image_name}" alt="#{I18n.t('controllers.journal.lock_icon')}" />|
      end
      
      def feed(args)
        %|<link rel="alternate" type="application/atom+xml" title="Atom feed" href="#{journal.feed_url(@privileged_reader)}" />|
      end
    end
    
    module BlockCommands
      def entry(args, inner)
        post.entry? ? inner : ""
      end

      def page(args, inner)
        # I'm not sure if all fake entries should be classified as pages for this purpose.
        # For now, it's just for the lorem entry.
        (post.page? or (post.fake_entry? and self.post.permaname == "lorem")) ? inner : ""
      end

      def open(args, inner)
        !post.locked? || (@privileged_reader && !@guest) ? inner : ""
      end
      
      def locked(args, inner)
        post.locked? ? inner : ""
      end

      def pre(args, inner)
        # Replace carriage returns and line feeds with escape characters
        # This will stop new line formatting from taking place within the block
        # Template::Formatting will process these back into the proper chars 
        inner.gsub(/\n/, "\e010").gsub(/\r/, "\e013")
      end
    end

    # Set up command aliases
    alias_command :entry, :normal
    alias_command :page, :special

    # Specify commands that shouldn't have their arguments pre-evaluated
    dont_pre_evaluate_args :entrylist, :lastfew
  
  protected
    # Syntax:
    #   ATTRIBUTE
    #   ENTRY <ATTRIBUTE ['exists']>
    # where:
    #   ENTRY     ::= ('first' | 'last' | 'prev' | 'next' | 'curr' | 'home' | 'archive' | 'split' | 'random')
    #   ATTRIBUTE ::= ('title' | 'url' | 'link' ...)
    def inline_command_missing(name, args)
      name = name.downcase
      exists = extract_from_args!(args, 'exists')
      
      post_name, post, attr_name = nil
      
      name_is_attr = (name =~ ATTRS_REGEX)

      if name_is_attr 
        attr_name = name
      else
        attr_name = extract_from_args!(args, ATTRS_REGEX)
        post_name = name
        post = find_post(post_name) if !attr_name.nil? or exists

        raise Papyrus::UnknownSubError if post.nil? and !exists and post_name !~ ENTRY_NAMES_REGEX
      end

      if exists && post.nil?
        return ""
      else
        if post_name == 'home' && attr_name =~ /^(url|link)$/
          # [home url] and [home link] are special cases that link to the journal home instead of
          # to a specific post
          case attr_name
            when 'url'
              journal.home_url + persistent_url_vars
            when 'link'
              link_text = args.empty? ? Post.link_text['home'] : args.join(" ")
              '<a href="' + journal.home_url + persistent_url_vars + '">' + link_text + '</a>'
          end
        else
          if attr_name
            post_name ? attr(post_name, attr_name, args) : attr(attr_name, args)
          elsif !exists
            raise Papyrus::UnknownSubError
          else
            args.join(" ")
          end
        end
      end
    end
    
    # 1) [title]               ==> attr('title')
    #    [link some text]      ==> attr('link', ['some', 'text'])
    # 2) [prev title]          ==> attr(Post.new, 'title') 
    #    [prev link some text] ==> attr(Post.new, 'link', ['some', 'text'])
    def attr(*all_args)
      using_active_post = false

      if all_args.first =~ ENTRY_NAMES_REGEX
        # Dealing with a page 'type' (prev, next, etc.)
        post = find_post(all_args.first)
        post_name = all_args.shift
        post_name.downcase!
      else
        # Check if the first arg is a page name
        post = find_post(all_args.first) if !%w(url title link parent parents children).include?(all_args.first)
        if post.nil? 
          post = self.post
          using_active_post = true
        else
          post_name = all_args.shift
          post_name.downcase! if post_name.is_a?(String)
        end
      end

      attr_name, args = all_args
      attr_name.downcase!

      case attr_name
      when 'url'
        post ? post.url + persistent_url_vars : '#'
      when 'title'
        post ? h(post.processed_title) : ""
      when 'link'
        link_text = (args.empty? && !using_active_post) ? Post.link_text[post_name] || post.title : args.join(" ")
        post ? post.link(link_text, persistent_url_vars) : link_text
      end
    end
    
    # Use the journal tied to the template being viewed, or use the logged in user's
    # journal if we're not rendering a template here
    def journal
      @journal ||= (@cdx_template ? @cdx_template.journal : @current_journal)
    end
    
    # Use temporary post assigned during generate_list, or the post being viewed
    def post
      @post ||= @cdx_template.active_post
    end
    
    def include_private?
      @current_journal && journal == @current_journal
    end
  
    def get_entries_ordered_by_time(order)
      conditions = "privacy != 'C'" unless include_private?
      journal.entries.all(:conditions => conditions, :order => "posted_at #{order}")
    end
    
    def get_archive_format
      journal.config.entrylists.andand.archiveformat
    end

    def handle_split(posts, format, order)
      out = Papyrus::SeparateString.new 
      
      # Determine what year/month a post falls into
      # Done in Rails as opposed to in the db in order to take timezones into account
      yearmonths = Hash.new { |h,k| h[k] = Array.new }
      posts.all(:select => "posts.id, posts.posted_at").each do |p|
        yearmonths["%d-%02d" % [p.posted_at.year, p.posted_at.month]] << p.id
      end

      yearmonths.sort.reverse.each do |ym|
        ym, post_ids = ym
        y, m = ym.split("-").map(&:to_i)

        posts_in_month = posts.scoped(:conditions => {:id => post_ids})

        out << %|<h4 class="entrylist">#{I18n.l(Time.zone.local(y, m), :format => journal.config.formatting.time.month)}</h4>| + "\n"
        out << generate_list(posts_in_month, format, order)
      end

      out
    end

    def generate_list(posts, format, order="asc", limit=nil)
      format = get_archive_format if format.blank?
      format = %Q|<b>[time "%H:%0M, %Y-%0m-%0d"]:</b>&nbsp; [link [title]]| if format.blank?
      
      out = ""
      if journal.config.entrylists.andand.lockicon?
        out << %|<link rel="stylesheet" href="/stylesheets/archive.css" />|
      end
      
      if String === format
        # we have to parse the format as a separate template (but not evaluate it yet)
        template = @template.clone_with(format)
        template.analyze
        format = template.parser.document
      else
        # we've already parsed the format, now we just have to ensure it is a separate template
        template = @template.clone
        format = template.parser.document = Papyrus::Document.new(template.parser, format)
      end
      template.options[:allowed_commands] = template.allowed_commands = %w(time url title link locked lock_icon home)
      template.shielded_commands.clear
      
      out << %|<ul class="entrylist">| + "\n"
      #times = [] # for benchmarking purposes
      #puts_time "posts.find_each total time" do
        posts.paginated_each(
          :per_page => (limit || 1000),
          #:include => [:journal, {:journal => :user}],
          :order => "posted_at #{order}",
          :limit => limit
        ) do |post|
          #t = Benchmark.realtime do
            post.show_untitled!
            
            # remember that format2 is a document. so now reset and re-evaluate it
            template.custom_commands.post = post
            
            # Let the template think that the current journal is the one that corresponds to the given post
            # Allows journaltitle, username, etc. work when listing other journal's posts
            template.custom_commands.journal = post.journal
            template['journaltitle'] = template['journal_title'] = post.journal.title 
            template['username'] = post.journal.user.username

            format2 = format.clone
            entrylist = format2.evaluate.join

            out << (post.locked? ? %|<li class="locked">| : %|<li>|)
            out << entrylist
            out << %|</li>| + "\n"
          #end
          #times << t
        end
        #RAILS_DEFAULT_LOGGER.debug Color.red("Sum of iteration times: #{times.sum} | Number of iterations: #{times.size} | Average iteration time: #{times.sum / times.size}")
      #end
      out << %|</ul>| + "\n"

      return out
    end
 
    def find_post(name)
      @find_post[name] ||= case name
        when "curr", "last"   then journal.current_entry(include_private?)
        when "first"          then journal.posts.first_entry(include_private?)
        when "prev"           then @cdx_template.active_post.prev(include_private?)
        when "next"           then @cdx_template.active_post.next(include_private?)
        when "home"           then journal.start_page(include_private?)
        when "archive"        then
          # If the current page is an archive, don't load a new one because the [archivedate] will have already been substituted in the title
          if self.post.archive_layout? and self.post.permaname == "archive"
            self.post
          else
            journal.posts.find_fake_by_name("archive")
          end
        when "split"          then journal.posts.find_fake_by_name("split")
        when "random"         then journal.entries.random(@cdx_template.active_post.id, include_private?)
        # [page:PAGENAME ATTR] (e.g. link to a page)
        else                  journal.pages.find_by_permaname(name.gsub(/^(?:s(pecial)?|p(age)?):/, ''))
      end
    end
   
    def post_exists?(name)
      not find_post(name).nil?
    end
    
    # Pluck the first occurrence of the keyword out of the args, case insensitively
    # Account for the fact that there may be non-Strings (to wit, nodes) in the array
    def extract_from_args!(args, val)
      for arg in args
        darg = arg.to_s.downcase
        if val === darg
          args.delete(arg)
          return darg
        end
      end
      return nil
    end

    # Put together a query string to append to URLs generated by subs
    def persistent_url_vars
      parts = {}
      parts[:template] = @cdx_template.name if @persist_template
      parts[:guest] = 1 if @guest
      parts.length > 0 ? "?" + parts.make_query_string : ""
    end 

    def list_categories(categories, class_name, as_list = false, show_counts = false)
      return "" if categories.nil?
      category_list = []
      [categories].flatten.each do |category|
        count = show_counts ? %| <span class="category-count">(#{category.post_categories.count})<span>| : ""
        if as_list
          category_list << %|<li><a href="#{category.link(journal.user)}#{persistent_url_vars}">#{h(category.name)}</a>#{count}</li>| + "\n"
        else
          category_list << %|<a href="#{category.link(journal.user)}#{persistent_url_vars}">#{h(category.name)}</a>#{count}|
        end
      end

      if as_list
        Papyrus::SeparateString.new(%|<ul class="#{class_name}">#{category_list.join}</ul>| + "\n")
      else
        %|<span class="#{class_name}">#{category_list.join(", ")}</span>|
      end
    end

    def format_time(time, args)
      return "" if time.nil?
      if format = args.shift
        # default conversion specifications to non-zero-padded
        %w(d g I j m U V W).each do |f|
          format.gsub!("%"+f) { time.strftime("%"+f).to_i.to_s }
        end
        format.gsub!(/%0(\w)/, "%\\1")
        # Add custom formats
        format.gsub!("%f") { time.day.ordinalize }
        I18n.l(time, :format => format)
      else
        I18n.l(time, :format => :long)
      end
    end

    def archive_range(info = {})
      return nil if info.nil? or info.empty?

      info = {"year" => nil, "month" => nil, "day" => nil}.merge(info)
      year, month, day = info["year"], info["month"] || 1, info["day"] || 1
      return -1 unless Date.valid_date? *[year, month, day].map(&:to_i)

      range_start = Time.zone.local(year.to_i, month.to_i, day.to_i)
      range_end = (!info['day'].nil? ? range_start + 1.day : !info['month'].nil? ? range_start + 1.month : range_start + 1.year) - 1.second
      return [range_start, range_end]
    end

    def archive_link(date_hash, args)
      if date_hash
        parts = ["%04d" % date_hash.posted_at.year]
        parts << "%02d" % date_hash.posted_at.month if @archive_info["month"]
        parts << "%02d" % date_hash.posted_at.day if @archive_info["day"]

        date_hash = {"year" => date_hash.posted_at.year, "month" => date_hash.posted_at.month, "day" => date_hash.posted_at.day}.delete_if { |k,v| @archive_info[k].nil? }
        link_text = args.empty? ? formatted_archive_date(date_hash) : args.join(" ").gsub("[date]", formatted_archive_date(date_hash))
        '<a href="' + find_post("archive").url / parts.join("/") + persistent_url_vars + '">' + link_text + '</a>'
      else
        ""
      end
    end

    def formatted_archive_date(arr = nil)
      if arr.nil?
        @formatted_archive_date ||= get_formatted_archive_date(@archive_info)
      else
        get_formatted_archive_date(arr)
      end
    end

    def get_formatted_archive_date(arr)
      year, month, day = arr["year"], arr["month"] || 1, arr["day"] || 1
      date = Time.zone.local(year.to_i, month.to_i, day.to_i)
      if arr["day"]
        format = journal.config.formatting.time.full
      elsif arr["month"]
        format = journal.config.formatting.time.month
      else
        format = journal.config.formatting.time.year
      end
      format_time(date, [format.dup])
    end

    # HMM, MAYBE WE'LL DO SOMETHING WITH THIS LATER
    #def helper
    #  @helper ||= begin
    #    ActionController::Base.helpers.class_eval do
    #      extend ApplicationHelper
    #    end
    #  end
    #end

  end # CustomCommands
end # Template
