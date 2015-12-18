# == Schema Information
# Schema version: 20080712010244
#
# Table name: templates
#
#  id         :integer(11)     not null, primary key
#  journal_id :integer(11)     not null
#  name       :string(40)      default(""), not null
#  created_at :datetime        not null
#  updated_at :datetime        not null
#

class Template < ActiveRecord::Base
  module AssocExtensions
    def find_fake_by_name(name)
      raise "Proxy owner must be a Journal" unless proxy_owner.is_a?(Journal)
      journal = proxy_owner
      name = name.to_s
      return unless Template.fake_template_names.include?(name)
      now = Time.now
      journal.templates.build(
        :name => name,
        :raw_content => File.read(Template.filepath_for_fake_template(name)),
        :updated_at => now,
        :fake => true
      )
    end
  end
  
  FAKE_TEMPLATES_EXT = 'txt'
  
  attr_accessor :post
  
  attr_writer :content
  attr_lazy :raw_content
  
  # used during the journal import process
  attr_accessor :filename
  
  attr_accessor :fake
  
  # used in the new/edit template form
  boolean_attr_accessor :make_default
  
  remembers_changes_since_last_saved
  
  #=== Associations ===
  
  # for each post tied to this template, set its template_id to null if this template is deleted
  has_many :posts, :dependent => :nullify
  belongs_to :journal
  
  #=== Validations ===
  
  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :journal_id, :case_sensitive => false
  
  #=== Callbacks ===
  
  before_validation :normalize_name  
  before_save :reset_default_template

  #=== Named scopes ===

  named_scope :prefabs, :conditions => "type = 'Prefab'"
  named_scope :custom, :conditions => "type = 'Template'"
  
  def self.run_through_erb(content, ivars = {})
    tpl = ivars.delete('template')
    return content if tpl.nil?

    # this is basically what ActionController's render() does
    ivars.each {|k,v| tpl.assigns[k] = v }

    ActionView::InlineTemplate.new(content).render(tpl)
  end
  
  #=== Fake template stuff ===
  
  class << self
    def fake_templates_dir
      Codexed.config.dirs.fake_templates_dir
    end
  
    def fake_template_names
      @fake_template_names ||= Dir["#{fake_templates_dir}/*.#{FAKE_TEMPLATES_EXT}"].map do |file|
        File.basename(file, ".#{FAKE_TEMPLATES_EXT}")
      end
    end
  
    def filepath_for_fake_template(name)
      fake_templates_dir / name+".#{FAKE_TEMPLATES_EXT}"
    end
  end
  
  #=== Booleans ===
  
  # Determines if this template is the default for the journal
  def default?
    template = self.journal.default_template || self.journal.fallback_template
    self.name == template.name
  end

  def prefab?
    self.is_a? Prefab
  end
  
  def fake?
    @fake
  end
  
  #=== Legacy file stuff ===
  
  def old_raw_content
    unless @old_raw_content || new_record? || !File.exists?(self.filepath)
      logger.info "Reading template from file: #{self.filepath}"
      @old_raw_content = File.read(self.filepath)
    end
    @old_raw_content || ""
  end
  
  def filepath
    self.journal.user.templates_dir / "#{self.name}.rhtml"
  end
  
  def file_exists?
    File.exists?(filepath)
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

  attr_writer :active_post
  def active_post
    raise "Active post not defined" unless @active_post
    @active_post
  end
  
  def url
    "#{self.journal.home_url}/lorem?template=#{self.name}"
  end
  
  # note that attr_lazy already defines raw_content, so save it
  alias_method :orig_raw_content, :raw_content
  def raw_content
    # ensure that raw_content never returns nil
    orig_raw_content.to_s
  end
  
  #=== Actions ===
  
  def render(current_user = nil, ivars = {}, extra_options = {})
    # Don't bother parsing if there's nothing to parse
    return "" if self.raw_content.blank?
    
    post = self.active_post
    
    extra_options.reverse_merge!(:cdx_template => self, :current_user => current_user)
    unless post.body
      # Ensure that smart quotes and such are replaced AFTER subs in the body are replaced
      extra_options[:process_body] = lambda {|parsed_body| post.process_body(parsed_body, ivars) }
    end
    template = Papyrus::Template.new(self.raw_content,
      :custom_command_class => CustomCommands,
      :extra => extra_options
    )
    
    # Set up user variables
    for sub in self.journal.subs
      template[sub.name.downcase] = sub.value
    end
    # Set up template variables (these override user variables)
    template['journaltitle'] = template['journal_title'] = self.journal.title
    template['username'] = self.journal.user.username
    template['timestamp'] = template['datestamp'] = post.timestamp
    
    # Finally, tell the parser about the body, which is a variable but gets evaluated like [include]
    template['body'] = post.body || post.raw_body

    # Okay, replace those subs!
    template.render
  end
  
private
  # This is called before the template is validated on save:
  def normalize_name
    #self.name = self.name.gsub(" ", "+")
    self.name = self.name.gsub(%r{[/.]}, "")[0..39] if !self.name.nil?
  end

  # Called before the template is saved
  def reset_default_template
    @config = self.journal.config
    prev_name = attributes_when_last_saved['name']

    if @config.default.template == prev_name and prev_name != self.name
      @config.default.template = self.name
      @config.save
    end
    logger.info "Default template is now: #{self.journal.config.default.template}"
  end

end

# Moved from the Papyrus initializer since this within dev mode this command only works once
# This is due to ActiveSupport's reloading behavior - after the first request, BuiltinCommands
# is unloaded and hence doesn't extend the lexicon anymore, and we can't do anything
# about it since the initializer isn't loaded again until the server is restarted
# Since Template will always be referred to before BuiltinCommands this should solve the issues
Papyrus::Lexicon.extend_lexicon(Template::BuiltinCommands)
