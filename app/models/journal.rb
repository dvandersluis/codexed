# == Schema Information
# Schema version: 20080712010244
#
# Table name: journals
#
#  id         :integer(11)     not null, primary key
#  user_id    :integer(11)     not null
#  title      :string(70)      default(""), not null
#  listed     :boolean(1)      default(TRUE)
#  created_at :datetime        not null
#  updated_at :datetime        not null
#

class Journal < ActiveRecord::Base
  class JobWrapper
    attr_reader :job
    
    def initialize(journal)
      @journal = journal
      @user = journal.user
      @underscored_class = self.class.to_s.demodulize.underscore
      @job = @journal.send("#{@underscored_class}_job")
    end
    
    def queued?
      !@job.nil?
    end
    
    def method_missing(name, *args)
      @job.andand.send(name, *args)
    end
  end
  
  class Export < JobWrapper
    def tmpdir
      @user.userspace_dir / "export"
    end
    
    def outfile
      tmpdir / "out.zip"
    end
  end
  
  class Import < JobWrapper
    def tmpdir
      @user.userspace_dir / "import"
    end
    
    def infile
      tmpdir / "in.zip"
    end
    
    def outfile
      tmpdir / "out.yml"
    end
    
    def data
      @data ||= YAML.load_file(outfile) if File.exists?(outfile) rescue nil
    end
  end
  
  belongs_to :user
  belongs_to :language
    
  with_options :dependent => :destroy, :extend => Post::AssocExtensions do |p|
    p.has_many :posts
    p.has_many :entries, :conditions => { :type_id => 'E' }, :class_name => "Post"
    p.has_many :pages, :conditions => { :type_id => 'P' }, :class_name => "Post"
  end
  
  has_many :templates,        :dependent => :destroy, :extend => Template::AssocExtensions
  has_many :prefabs,          :dependent => :destroy, :class_name => "Prefab"
  has_many :subs,             :dependent => :destroy, :order => "name"
  has_many :categories,       :dependent => :destroy
  has_many :archive_layouts,  :dependent => :destroy, :extend => ArchiveLayout::AssocExtensions

  has_many :tags, :through => :posts

  with_options :class_name => "MonitorableJob" do |j|
    j.with_options :conditions => { "jobs.worker_class" => "ImportWorker" } do |j|
      j.has_one :import_job, :order => "jobs.created_at DESC"
      j.has_many :import_jobs
    end
    j.with_options :conditions => { "jobs.worker_class" => "ExportWorker" } do |j|
      j.has_one :export_job, :order => "jobs.created_at DESC"
      j.has_many :export_jobs
    end
  end
  
  validates_presence_of :title
  validates_length_of   :title, :maximum => 70
  validates_presence_of_one_of :journal_password, :crypted_journal_password, :if => Proc.new {|journal| journal.privacy == 'P'}, :message => :password_required

  crypted_password :journal_password, :entries_password
  attr_uniquely_generated(:feed_key, :on => :create) { String.random(13) }
  
  scope_state :privacy, :public => "O", :protected => "P", :private => "C"
  def locked?; protected? or private?; end
  
  default_scope :include => :user
  
  # Provides access to the config variables for this journal. These variables are located
  # in a YAML file in the user's userspace, with the Configuration class dealing directly
  # with that file. A skeleton of that file is located in data/skel.
  def config
    @config ||= Configuration.new(self).load
  end
  
  def import
    @import ||= Import.new(self)
  end
  def export
    @export ||= Export.new(self)
  end

  def default_template
    self.templates.find_by_name(self.config.default.template)
  end
  
  def fallback_template
    self.templates.find_fake_by_name('main')
  end

  # Define the "start page" of the entry (the entry that is shown for the root url)
  def start_page(include_private = false)
    entry = nil
    if config.default.start_page
      entry = self.pages.find_by_permaname(config.default.start_page) || self.posts.find_fake_by_name(config.default.start_page)
    end
    entry || self.current_entry(include_private)
  end
  
  def current_entry(include_private = false)
    @current_entry ||= self.posts.current(include_private)
  end

  def home_url
    # this method is overridden when exporting a journal since the archive structure is different
    if meth = Thread.current['alt_journal_url_method']
      meth.call(self)
    else
      "http://#{self.user.username}.#{Codexed.base_domain}"
    end
  end
  
  def feed_url(private_feed)
    # just hard-code this url for now
    # maybe we'll have a way to hook into the journal_url helper at some point
    "/feed.atom" + ("/#{feed_key}" if private_feed).to_s
  end

  def template_options
    collection = templates.map(&:name) 
    collection.unshift([t(:use_site_default), ""]) if default_template.nil?
    collection
  end

  def start_page_options
    pages = self.pages.map{ |e| [e.title, e.permaname] }
    start_pages = [['', [[t(:current_entry), ""], [t(:archive), "archive"], [t(:split), "split"]]]]
    start_pages.push([t('models.page', :count => 2), pages]) unless pages.empty?
    start_pages
  end

  def sorted_categories
    categories.roots.sort_by(&:name)
  end

  def locked_journal_cookie
    :journal_authentication
  end

  def locked_post_cookie
    :post_authentication
  end

  def tagged_posts(tag)
    posts.find(:all, :include => :tags, :conditions => { "tags.name" => tag.name }) 
  end

  #=== Actions ===
  
  def import!(options, &block)
    self.import_jobs.destroy_all
    self.import_jobs.enqueue!(ImportWorker, :start, [self.id, (options || {})], :tmpdir => self.import.tmpdir, &block)
  end
  
  def export!
    self.export_jobs.destroy_all
    self.export_jobs.enqueue!(ExportWorker, :run, [self.id], :tmpdir => self.export.tmpdir)
  end
  
  def reset_attributes(*attrs)
    return if attrs.empty?
    temp_journal = Journal.new(:user => user, :title => user.username + "'s Journal")

    journal_params = {}
    attrs.flatten.each do |key|
      journal_params[key.to_s] = temp_journal[key.to_s]
    end          
    self.attributes = journal_params
  end
  
  class << self
    # Return the n most recently updated listed journals
    def recently_updated(n = 10)
      return nil if Journal.count == 0

      Journal.find_by_sql "SELECT j.*
        FROM journals AS j
        LEFT JOIN posts AS p
          ON p.id = j.current_entry_id
        WHERE j.privacy != 'C'
          AND j.listed = true
          AND p.id IS NOT NULL
        ORDER BY p.created_at DESC
        LIMIT #{n}"
    end

    # Sorts a collection of journals by posted_at
    # By default, private entries are skipped. To include them, pass true as the second parameter
    def sort_journals_by_created_at(collection, include_private = false)
      collection.sort do |one, two|
        one = one.journal if one.is_a?(UserFavorite)
        two = two.journal if two.is_a?(UserFavorite)

        e1 = one.nil? ? nil : one.current_entry(include_private)
        e2 = two.nil? ? nil : two.current_entry(include_private)

        ret = if e1.nil? and e2.nil?
          if one.nil? and two.nil?
            0
          elsif one.nil? and !two.nil?
            1
          elsif !one.nil? and two.nil?
            -1
          else
            one.user.username <=> two.user.username
          end
        elsif e1.nil? and !e2.nil?
          1
        elsif !e1.nil? and e2.nil?
          -1
        else
          e2.created_at <=> e1.created_at
        end

        if ret == 0 and !one.nil? and !two.nil? # If the two journals have an equal last updated date, sort by username
          one.user.username <=> two.user.username
        else
          ret
        end
      end
    end
  end

end
