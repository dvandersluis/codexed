# == Schema Information
# Schema version: 20080712010244
#
# Table name: posts
#
#  id                :integer(11)     not null, primary key
#  journal_id        :integer(11)     not null
#  template_id       :integer(11)     
#  title             :string(255)     default(""), not null
#  permaname         :string(60)      default(""), not null
#  summary           :text            
#  type_id           :string(1)       default("N"), not null
#  created_at        :datetime        not null
#  posted_at :datetime        not null
#  updated_at        :datetime        not null
#
#
# TODO: These methods need to be reorganized by type, they've kind of started to be helter-skelter
# 

class Post < ActiveRecord::Base
  
  FAKE_ENTRIES_EXT = 'txt'
  
  module AssocExtensions
    def find_fake_by_name(name, vars={})
      journal = proxy_owner
      post = Post.fake_entries[name] or return
      post.journal = journal
      
      # For archive pages, use the latest entry's time as the fake entry's time,
      # or the current time if there aren't any entries in the journal yet
      # Otherwise, just use the current time
      now = Time.now
      post.created_at = now
      post.posted_at = (journal.current_entry and (name =~ /archive/ || name == 'split')) ? journal.current_entry.posted_at : now
      
      # We need to set the title here for the category archive fake entry, since there's
      # no way for it to know which category is being viewed unless we tell it
      post.title = case name
        when "archive"            then Post.t(:entry_archive)
        when "split"              then Post.t(:entry_split_archive)
        when "category_archive"   then Post.t(:category_archive)
        when "tag_archive"        then Post.t(:tag_archive)
        when "new_journal"        then Post.t(:new_journal)
        when "lorem"              then "Lorem Ipsum" # Not English, doesn't need a translation
        when "entry_not_found"    then Post.t(:entry_not_found)
        when "category_not_found" then Post.t(:category_not_found)
      end

      # Add some tags and categories to the lorem entry
      if name == "lorem"
        post.tags = Tag.all(:limit => 3, :order => "RAND()") # Grab 3 random tags
        post.categories = [Category.new(:name => "Test Category 1", :slug => 'test-category-1'), Category.new(:name => "Test Category 2", :slug => 'test-category-2')]
      end

      # Specify HTTP response status if fake entry corresponds to a 404 page
      post.http_response_status = :not_found if name =~ /_not_found\z/i 

      post
    end
  end
  
  attr_accessor :http_response_status # Can be used to set what HTTP response status this post wants to return

  # if this is set instead of raw_body it means that the body won't be run through process_body below
  attr_accessor :body
  attr_lazy :raw_body
  
  attr_accessor :user_id, :tag_id

  attr_writer :autoupdate_permaname
  def autoupdate_permaname
    @autoupdate_permaname.nil? ? new_record? : @autoupdate_permaname.to_b
  end
  alias_method :autoupdate_permaname?, :autoupdate_permaname

  attr_writer :attr_names
  remembers_changes_since_last_saved
  
  # Rename Rails' default inheritance column ("type") so we can use it for other things
  self.inheritance_column = "klass" if method_defined?(:inheritance_column)
  
  #=== Associations ===
  
  belongs_to :journal
  belongs_to :template

  has_many :post_categories
  has_many :categories, :through => :post_categories
  
  has_many :post_tags
  has_many :tags, :through => :post_tags, :validate => false
  
  #=== Validations ===
  
  validates_presence_of :permaname
  validates_length_of :title, :maximum => 255, :allow_nil => true
  validates_length_of :permaname, :maximum => 60, :allow_nil => true
  
  validate :posted_at_must_be_valid_timestamp # this must go first
  validate :permaname_must_be_unique, :unless => :entry?  # since we're going to fix the permaname anyway if it conflicts
  validate :validate_tags
  
  #=== Callbacks (in order of execution) ===
  
  before_validation           :put_together_posted_at!
  before_validation           :generate_permaname
  before_validation           :fix_permaname_conflict!, :if => [:entry?, :permaname_is_not_unique?]
  before_validation           :update_tags
  #>> (validation happens here)
  before_save                 :normalize_permaname
  after_timestamps_on_create  :set_posted_at_if_necessary  
  #>> (save happens here)
  after_save                  :update_current_entry_id
  after_destroy               :update_current_entry_id
  
  #=== States ===
  
  scope_state :type_id, :entries => "E", :pages => "P", :fake => "F", :archive_layout => "A"
  alias_method :entry?, :entries?
  alias_method :page?, :pages?
  alias_method :fake_entry?, :fake?

  scope_state :privacy, :public => "O", :protected => "P", :private => "C"
  def locked?; protected? or private?; end
  
  #=== Fake entry stuff ===

  class << self
    def fake_entries_dir
      Codexed.config.dirs.fake_entries_dir
    end
  
    def fake_entry_names
      @fake_entry_names ||= Dir["#{fake_entries_dir}/*.#{FAKE_ENTRIES_EXT}"].map do |file|
        File.basename(file, ".#{FAKE_ENTRIES_EXT}")
      end
    end
  
    def fake_entry_filepath(name)
      fake_entries_dir / name+".#{FAKE_ENTRIES_EXT}"
    end
    
    def fake_entries
      # preload the fake entry array on first invocation
      # this is to speed journal exports up as we don't have to create a brand new Post every time we have to use a fake entry
      @fake_entries ||= fake_entry_names.inject({}) {|h, name| h[name] = build_fake(name); h }
    end
    
    def build_fake(name)
      entry = Post.new
      # set the base attributes
      entry.raw_body = File.read(fake_entry_filepath(name))
      entry.attributes = {
        :type_id => "F",
        :permaname => name
      }
      entry
    end
  end
  
  def self.link_text
    {
      'last' => t(:last_entry),
      'first' => t(:first_entry),
      'prev' => t(:prev_entry),
      'curr' => t(:curr_entry),
      'next' => t(:next_entry),
      'home' => t(:home_entry),
      'archive' => t(:archive_entry),
      'split' => t(:archive_entry),
      'random' => t(:random_entry)
    }
  end
  
  #=== Actions ===
  
  def self.generated_permaname(str)
    return nil if str.nil?

    permaname = str.
      gsub(/<\/?[^>]*>/, "").                     # remove HTML tags
      decode_entities.                            # replace HTML entities with the correct character
      uninternationalize.                         # replace international characters with basic latin ones
      gsub(/\s*[&]\s*/, " and ").                 # convert "&" to " and "
      # -- TODO: translate special dashes here --
      gsub(/[^a-z0-9_ -]/i, "").                  # remove all characters other than alphanumeric, underscore, dash and space
      gsub(/([a-z0-9])_+([a-z0-9])/i, "\\1-\\2"). # replace underscores in between alphanumeric characters with dashes
      squeeze(" ").                               # squeeze multiple spaces
      gsub(/\s/, "-").                            # replace spaces with dashes 
      squeeze("-").                               # squeeze multiple dashes
      word_truncate(permaname_length, "-").       # trim the string to the permaname length (but don't cut off any words)
      gsub(/^-|-$/, '').                          # remove dashes from the start and end of the string
      downcase                                    # you can probably guess what this does ;)
    
    permaname = "untitled" if permaname.blank?
    return permaname
  end
  
  def render(current_user = nil, ivars = {}, extra_options = {})
    render_with_template(self.template, current_user, ivars, extra_options)
  end
  def render_without_template(current_user = nil, ivars = {}, extra_options = {})
    render_with_template self.journal.templates.build(:raw_content => "[body]"), current_user, ivars, extra_options
  end
  def render_with_template(template, current_user = nil, ivars = {}, extra_options = {})
    if new_record?
      self.created_at = Time.now
      self.posted_at ||= Time.now
    end
    template.active_post = self
    template.render(current_user, ivars, extra_options)
  end
  
  #=== Pseudo-attributes ===
    
  # shortcut to calling journal.user
  # XXX this is unnecessary as calling journal.user does NOT load journal record
  def user
    @user ||= User.find_by_sql([
      "SELECT u.* FROM users AS u JOIN journals AS j ON j.user_id = u.id WHERE j.id = ? LIMIT 1",
      journal_id
    ])[0]
  end
  
  alias_method :assigned_template, :template
  def template
    # If somehow the assigned template doesn't belong to this journal, use the fallback
    (self.assigned_template if self.assigned_template.andand.journal == self.journal) || self.journal.default_template || self.journal.fallback_template
  end

  # I don't know if this will happen automatically but I don't want to take any chances
  def template_id=(id)
    self['template_id'] = id.blank? ? nil : id
  end
  
  def title(untitled = true)
    title = self[:title]
    title = t(:untitled) if title.blank? and (untitled or show_untitled?)
    title
  end

  attr_accessor :show_untitled
  def show_untitled!
    self.show_untitled = true
  end
  def show_untitled?
    self.show_untitled
  end

  # used for journal exporting
  def filename
    (entry? ? [posted_at.to_s(:squeezed), permaname].join("_") : permaname)
  end
  
  # used in the new/edit entry form
  boolean_attr_accessor :use_server_time

  #=== Time stuff ===
  
  attr_writer :month, :day, :year, :hour, :minute, :second, :ampm
  
  def month
    @month ||= created_stamp.strftime('%m')
  end
  def day
    @day ||= created_stamp.strftime('%d')
  end  
  def year
    @year ||= created_stamp.strftime('%Y')
  end
  def hour
    @hour ||= (t('locale.clock_type').to_i == 12 ? created_stamp.strftime('%I') : created_stamp.strftime('%H'))
  end
  def minute
    @minute ||= created_stamp.strftime('%M')
  end
  def second
    @second ||= created_stamp.strftime('%S')
  end
  def ampm
    @ampm ||= created_stamp.strftime('%p')
  end

  def timestamp
    self.created_at.utc.strftime("%Y%m%d%H%M%S") + self.id.to_s
  end
  
  #=== Tag methods ===
  attr_writer :tag_names
  def tag_names
    tags.map(&:name).join(", ")
  end
  
  def build_tags
    # This is used when previewing an entry. We just need to load the association
    # with some records so post.tags will return something, so [tags] will return something
    return unless @tag_names
    @tag_names.split(",").each {|name| tags.build :name => name }
  end

  def update_tags
    # Map @tag_names to the actual tags association
    # Note that tags= cannot be used because when updating a record, the association will be saved immediately
    # when using tags=, which will cause an exception to be raised if there is an invalid tag.
    return unless @tag_names
    
    existing_tag_names = tags.map(&:name)
    given_tag_names = @tag_names.split(",").map(&:strip).uniq
    
    # add in new tags
    given_tag_names.each do |name|
      next if existing_tag_names.include?(name)
      if t = Tag.find_by_name(name)
        tags << t
      else
        tags.build :name => name
      end
    end
    
    # remove dropped tags
    removed_tags = (existing_tag_names - given_tag_names).map { |name| Tag.find_by_name(name) }
    tags.delete(*removed_tags) unless removed_tags.nil?
  end

  def validate_tags
    tags.each do |tag|
      if !tag.valid?
        tag.errors.each do |name, message|
          errors.add(:tag, "(#{tag.name}) #{message}")
        end
      end
    end
  end
  
  private :update_tags, :validate_tags
  
  #=== Navigation methods ===
  
  def processed_title
    Template::Formatting.format(self.title(false), self.journal.config.formatting, [:apply_text_styles, :apply_typographical_effects])
  end
  
  def url(relative = false)
    # this method is overridden when exporting a journal since the archive structure is different
    if meth = Thread.current['alt_entry_url_method']
      meth.call(self)
    else
      url = nil
      if entry?
        time = posted_at.in_time_zone(journal.config.time.zone)
        url = time.year.to_s / time.month.to_s.rjust(2, "0") / time.day.to_s.rjust(2, "0") / permaname
      else
        url = permaname
      end
      relative ? url : self.journal.home_url / url
    end
  end
  def self.url_for(type, permaname)
    type_id = convert_type(type)
    post = Post.new(:type_id => type_id, :permaname => permaname)
    post.url
  end

  def link(text, query_string = nil)
    url ? '<a href="' + url + query_string.to_s + '">' + text.to_s + '</a>' : text.to_s
  end

  def next(include_private = false)
    return if not entry?
    additional_conditions = "privacy != 'C' AND" unless include_private
    conditions = [
      "(#{additional_conditions} posted_at > :posted_at OR (posted_at = :posted_at AND id > :id))",
      { :posted_at => self.posted_at, :id => self.id }
    ]
    self.journal.entries.find(:first, :conditions => conditions, :order => 'posted_at ASC, id ASC') 
  end

  def prev(include_private = false)
    return if not entry?
    additional_conditions = "privacy != 'C' AND" unless include_private
    conditions = [
      "(#{additional_conditions} posted_at < :posted_at OR (posted_at = :posted_at AND id < :id))",
      { :posted_at => self.posted_at, :id => self.id }
    ]
    self.journal.entries.find(:first, :conditions => conditions, :order => 'posted_at DESC, id DESC')
  end

  #=== Legacy file stuff ===
  
  # Reads the post from the user's userspace and returns the contents.
  # The first time this is called, the result will be cached; subsequent calls just return the value.
  def old_raw_body
    if @raw_body.nil? && (!new_record? || fake_entry?) && file_exists?
      logger.info "Reading post from file: #{self.filepath}"
      @raw_body = File.read(self.filepath)
    end
    @raw_body
  end
  
  def file_exists?
    File.exists?(self.filepath)
  end
  
  def filepath
    if entry?
      created_at && (self.journal.user.entries_dir / created_at.utc.to_s(:squeezed)+"_"+permaname+'.txt')
    elsif page?
      self.journal.user.entries_dir / permaname+'.txt'
    elsif fake_entry?
      self.class.fake_entries_dir / permaname+'.txt'
    end
  end
  
  #=== Body stuff ===
  
  # The following is used when rendering the post:
  
  def process_body(body, ivars)
    body = self.class.clean_body(body)
    if fake_entry?
      begin
        body = Template.run_through_erb(body, ivars.merge('journal' => self.journal))
      rescue
        # Something screwed up when trying to process the fake entry, throw a 500
        body = Template.run_through_erb(Post.fake_entries['post_could_not_be_loaded'].raw_body, ivars.merge('journal' => self.journal))
        @http_response_status = :internal_server_error
      end
    else
      body = Template::Formatting.format(body, self.journal.config.formatting)
    end
    body
  end
  
  # note that attr_lazy already defines raw_body, so save it
  alias_method :orig_raw_body, :raw_body
  def raw_body
    # ensure that raw_body never returns nil
    orig_raw_body.to_s
  end
  
  # Necessary?
  #----
  # You can set the type like so:
  # - entry.type = "N"   # old-fashioned way
  # - entry.type = "n"
  # - entry.type = :n
  # - entry.type = :normal
  def type=(type)
    self.type_id = self.class.convert_type(type)
  end
  def type
    self.type_id.downcase
  end
  def full_type
    case type_id
      when "E" then "entry"
      when "P" then "page"
    end
  end
    
  #=== Finders ===

  class << self
    # DEPRECATED, use `e.entries` or `e.pages` instead
    #--
    # You can call this method like so:
    # - find_all_by_type 'n'
    # - find_all_by_type 'N'   # <= equiv. to find_all_by_type_id
    # - find_all_by_type :normal
    def find_all_by_type(type, options={})
      type_id = convert_type(type)
      find_all_by_type_id(type_id, options)
    end
    
    # DEPRECATED, use e.g. `entries.normal.find_by_permaname` instead
    def find_by_permaname_and_type(permaname, type)
      type_id = convert_type(type)
      post = find(:first, :conditions => { :permaname => permaname, :type_id => type_id })
      raise "Couldn't find post with type '#{type}' and permaname '#{permaname}'" unless post
      post
    end
    
    def find_from_url(params)
      type_id = convert_type(params[:type] || "n")
      name = params[:permaname]
      if type_id == "E"
        # entry
        month, day, year = params.values_at(:month, :day, :year).map(&:to_i)
        return nil unless Date.valid_civil?(year, month, day)
        time = Time.zone.local(year, month, day)
        find(:first, :conditions => [
          "posted_at BETWEEN ? AND ? AND permaname = ? AND type_id = ?",
          time.beginning_of_day.utc, time.end_of_day.utc, name, type_id
        ])
      else
        # page
        find(:first, :conditions => { :permaname => name, :type_id => type_id })
      end
    end
    
    def find_all_similar_from_url(params)
      permaname = params[:permaname]
      month, day, year = params.values_at(:month, :day, :year).map(&:to_i)
      return [] unless Date.valid_civil?(year, month, day) 
      time = Time.zone.local(year, month, day)
      # search only by permaname, then only by date
      [
        find(:all, :conditions => { :type_id => "E", :permaname => permaname }),
        find(:all, :conditions => [
          "type_id = 'E' AND posted_at BETWEEN ? AND ? AND permaname != ?",
          time.beginning_of_day.utc, time.end_of_day.utc, permaname
        ])
      ]
    end
    
    # Returns the first entry
    def first_entry(include_private = false)
      conditions = "privacy != 'C'" unless include_private
      entries.find(:first, :conditions => conditions, :order => 'posted_at asc, id asc')
    end

    # Returns the most recent entry.
    def current(include_private = false)
      conditions = "privacy != 'C'" unless include_private
      entries.find(:first, :conditions => conditions, :order => 'posted_at desc, id desc')
    end
    
    # Returns a random entry.
    # See <http://daniel.collectiveidea.com/blog/2007/5/17/the-road-to-randomness> for implementation.
    # Specifying an exclude ID will avoid getting the same record twice in a row
    def random(exclude = nil, include_private = false)
      offset_conds = "privacy != 'C'" unless include_private
      offset = rand(entries.count(:conditions => offset_conds))

      conditions = []
      conditions.push("privacy != 'C'") unless include_private

      if !exclude.nil? and exclude =~ /^\d+$/
        conditions.push("id != ?")
        offset -= 1 # since we're removing one record from the set
      end
      entries.find(:first, :conditions => [conditions.join(" AND "), exclude.to_i], :offset => offset)
    end
    
    # Finds all days on which an entry exists and returns
    # the result as an array of Date objects.
=begin
    def months
      connection.select_values(
        "SELECT DISTINCT DATE(posted_at) AS date
        FROM #{table_name}
        WHERE type_id = 'N'
        ORDER BY date"
      ).map {|date| Date.parse(date) }
    end
=end

    # converts e.g. "normal", :normal or :n to just "N"
    def convert_type(type)
      type.to_s.first.upcase
    end
    
    def permaname_length
      columns_hash['permaname'].limit
    end
  end # singleton
  
  # This is called before the post is saved
  boolean_attr_reader :permaname_conflict_fixed
  def generate_permaname(force = false)
    self.permaname = self.class.generated_permaname(self.title) if permaname.blank? or force
    
  end
  
  # Called before validation on save
  def put_together_posted_at!
    if use_server_time
      self.posted_at = Time.zone.now
      return
    end

    return if posted_at && new_record?
    return unless @month && @day && @year && @hour && @minute
    if @ampm
      hour_24 =
        if hour.to_i == 12
          (ampm == 'AM' ? 0 : 12)
        elsif ampm == 'PM'
          hour.to_i + 12
        else
          hour.to_i
        end
    else
      hour_24 = hour.to_i
    end
    self.posted_at = Time.zone.local(year.to_i, month.to_i, day.to_i, hour_24, minute.to_i) unless Date.valid_civil?(year.to_i, month.to_i, day.to_i).nil?
  end

private
  # Used when fixing a possible permaname conflict, or when checking that the permaname is unique
  def permaname_is_not_unique?
    statement = "journal_id = ? AND type_id = ? AND permaname = ?"
    vars = [ journal_id, type_id, permaname ]
    if entry?
      # check that there aren't multiple posts with same permaname on the same date
      statement << " AND DATE(posted_at) = ?"
      vars << ((!new_record? || posted_at) ? posted_at.to_date : Date.today)
    end
    unless new_record?
      # we're obviously resaving a record, so don't count this one
      statement << " AND id != ?"
      vars << id
    end
    #self.connection.uncached do
      self.class.count(:conditions => [statement, *vars]) > 0
    #end
  end

  # TODO: Cleanup this method
  def fix_permaname_conflict!
    #puts "Initial permaname is: '#{permaname}'"
    i = 0
    loop do
      i += 1
      raise "Infinite loop" if i == 10
      # Increment the index at the end of the permaname, or add one if the permaname doesn't have one
      # If this results in a permaname longer than max length, then chop off a word before
      #  modifying/applying the index
      # Note that throughout this we assume that this post's permaname doesn't have a suffix
      entries_with_permaname_suffix = self.journal.entries.all(
        :select => "permaname",
        :conditions => [
          "DATE(posted_at) = ? AND permaname REGEXP ?",
          self.posted_at.to_date, "^#{self.permaname}-[0-9]+$"
        ]
      )
      index =
        if entries_with_permaname_suffix.any?
          max_index = entries_with_permaname_suffix.map {|e| e.permaname =~ /-(\d+)/; $1.to_i }.max
          max_index + 1
        else
          2
        end
      suffix = "-#{index}"
      #puts "Suffix we'll be adding: '#{suffix}'"
      if (permaname + suffix).length > self.class.permaname_length
        prefix = nil
        if permaname.include?("-")
          pieces = permaname.split("-")
          #puts "Permaname is longer than limit, already has a dash"
          # Permaname has some sort of suffix
          # This may be a word at the end, or an index
          # Furthermore, an unknown number of indices may be present at the end
          seceip = pieces.reverse
          index_of_word = (0..seceip.size-1).find {|i| seceip[i] =~ /^[a-z]+$/ }
          if index_of_word
            index_of_next_word = (index+1..seceip.size-1).find {|i| seceip[i] =~ /^[a-z]+$/ }
            if seceip[0] =~ /^\d+$/ && index_of_next_word
              # There's an index or indices at the end and only one word before the index: truncate the word
              # e.g. aaaaaaaaaaaaaaaaaaaa...-2 + -2
              #      aaaaaaaaaaaaaaaaaa...-2-2 + -2
              seceip[index_of_word] = seceip[index_of_word][0...-suffix.length]
            else
              # There's an index or indices at the end and permaname contains more than one word:
              # Look for word before and chop it off
              # e.g. dkfkdlk-asdflkfsdfa-...-2 + -2
              #      aaa-bbb-...-1-ddd-2-eee-3 + -2
              # no index or indices at end: chop off a word
              # e.g. dkfkdlk-asdflkfsdfa-...aa + -2
              seceip.delete_at(index_of_word)
            end
          else
            # Permaname consists entirely of indices, which is, like, not cool, man
            # 2-2-2-2-2-2-2-2-2-2-...-2 + -2
            raise "Please don't game the system, thx"
          end
          prefix = seceip.reverse.join("-")
        else
          # Either permaname contains more than one word, or is one word
          # In any event, just truncate permaname
          prefix = permaname[0...-suffix.length]
          #puts "Permaname is longer than limit, doesn't have a dash"
        end
        #puts "Prefix is now: '#{prefix}'"
        self.permaname = prefix + suffix
        #puts "Permaname is now '#{permaname}'. Rechecking uniqueness..."
        redo if permaname_is_not_unique? # have to revalidate since we changed permaname, ugh
      else
        self.permaname += suffix
        #puts "Permaname is within limit, is now: '#{permaname}'"
      end
      break
    end
    #puts "Final permaname is: '#{permaname}'"
    @permaname_conflict_fixed = true
  end

  # This is called before the post is saved
  def normalize_permaname
    self.permaname = self.class.generated_permaname(self.permaname)
  end

  # Called after save 
  def update_current_entry_id  
    # Nothing needed to be done if this post isn't an entry.
    return if !entry?

    journal = self.journal
    current_id = journal.posts.current.id unless journal.posts.current.nil?

    self.journal.update_attributes(:current_entry_id => current_id) if journal.current_entry_id != current_id
    logger.info "Setting current_entry_id for journal #{journal.id} to #{journal.current_entry_id}"
  end

  # Validation routine
  # Note that this only runs when saving a page
  def permaname_must_be_unique
    return if permaname.blank?
    # If we've already adjusted the permaname, don't check that it's unique, since we essentially just did that
    return if @permaname_conflict_fixed
    errors.add(:permaname, :unique_permaname_p) if permaname_is_not_unique?
  end

  # Validation routine
  def posted_at_must_be_valid_timestamp
    date_segments = [:day, :month, :year, :hour, :minute, :second]
    date_segments.push(:ampm) if t('locale.clock_type').to_s.eql? "12"
    numeric = [:day, :year, :hour, :minute, :second]
    error = false

    date_segments.each do |segment|
      value = send(segment)
      if value.blank?
        errors.add(segment, :blank)
        error = true
      elsif numeric.include?(segment) and !value.to_s.match(/^\d+$/)
        errors.add(segment, :not_a_number)
        error = true
      end
    end
    return if error

    errors.add(:date_and_time, :not_a_date) if Date.valid_civil?(year.to_i, month.to_i, day.to_i).nil?
  end

  # This is called before the post is created
  # Really, this method is here for the unit test, as posted_at
  # will be overwritten by put_together_posted_at
  def set_posted_at_if_necessary
    self.posted_at ||= self.created_at
  end

  def self.clean_body(body)
    body.gsub(/\r/, '')
  end

  def created_stamp
    @created_stamp ||= (posted_at || Time.zone.now)
  end
end
