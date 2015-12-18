class Category < ActiveRecord::Base
  include ActionController::UrlWriter
  include UrlHelpersMixin
    
  validates_presence_of :name#, :slug
  validates_length_of :name, :maximum => 200 
  validates_length_of :slug, :maximum => 200 
  validates_uniqueness_of :name, :scope => [:journal_id, :parent_id]
  
  has_many :post_categories, :dependent => :destroy
  has_many :posts, :through => :post_categories
  belongs_to :journal

  acts_as_nested_set :dependent => :destroy, :scope => :journal
  
  before_validation :generate_slug
  before_save       :normalize_slug
  before_save       :validate_parent_id
  before_save       :make_private_if_parent_is
  after_save        :place_in_nested_set
  after_save        :update_descendant_privacy

  scope_state :privacy, :public => "O", :private => "C"

  #=== Nested set methods ===
  
  def add_as_child_of(target)
    target = self.journal.categories.find_by_id target if target.is_a? Fixnum or target.is_a? String
    raise ArgumentError, "target is invalid" if target.nil?

    children = (target.children + [self]).uniq.sort_by(&:name)
    pos = children.index(self)

    if children.empty? or pos == children.length - 1
      move_to_child_of target
    else
      target = children[pos + 1]
      move_to_left_of target unless self == target
    end
  end

  def validate_parent_id
    return true if parent_id.nil? or parent_id.blank?

    if self.id == parent_id
      attr = :parent_id
      error = :cannot_be_child_of_self
    elsif !self.journal.categories.map(&:id).include?(parent_id)
      attr = :parent_id
      error = :given_parent_is_invalid
    elsif descendants.map(&:id).include? parent_id
      attr = :parent_id
      error = :cannot_be_child_of_descendant
    end
  
    errors.add(attr, error) if error
    return error.nil?
  end

  def make_private_if_parent_is
    # If a category's parent is private, force the category to be private as well
    self.privacy = "C" if parent.andand.privacy == "C"
  end

  def update_descendant_privacy
    # If a category is private, any descendants should be forced private too
    self.descendants.each(&:save!) if self.privacy == "C"
  end
  
  def place_in_nested_set
    # should this raise ActiveRecord::Rollback in some case?
    # move_to_root and add_as_child_of both throw execptions instead of returning so I'm not sure it needs to

    if parent_id.nil?
      move_to_root
    else
      add_as_child_of parent_id unless self.parent_id == parent_id
    end
    return true
  end

  def parentage
    if @parentage.nil?
      @parentage = []
      ancestors.each do |node|
        @parentage.push node.slug
      end
    end
    @parentage
  end

  #=== Slug methods ===
  
  class << self
    def slug_length
      columns_hash['slug'].limit
    end
  end

  def self.generated_slug(str)
    return nil if str.nil?

    slug = str.gsub(/<\/?[^>]*>/, "").            # remove HTML tags
      decode_entities.                            # replace HTML entities with the correct character
      uninternationalize.                         # replace international characters with basic latin ones
      gsub(/\s*[&]\s*/, " and ").                 # convert "&" to " and "
      # TODO -- translate special dashes
      gsub(/[^a-z0-9_ -]/i, "").                  # remove all characters other than alphanumeric, underscore, dash and space
      gsub(/([a-z0-9])_+([a-z0-9])/i, "\\1-\\2"). # replace underscores in between alphanumeric characters with dashes
      squeeze(" ").                               # squeeze multiple spaces
      gsub(/\s/, "-").                            # replace spaces with dashes 
      squeeze("-").                               # squeeze multiple dashes
      first(slug_length).                         # trim the string to the slug length
      gsub(/^-|-$/, '').                          # remove dashes from the start and end of the string
      downcase
    
    return slug
  end

  attr_writer :autoupdate_slug
  def autoupdate_slug
    @autoupdate_slug.nil? ? new_record? : @autoupdate_slug.to_b
  end
  alias_method :autoupdate_slug?, :autoupdate_slug

  def generate_slug(force = false)
    self.slug = self.class.generated_slug(self.name) if slug.blank? or force
  end
  
  def normalize_slug
    self.slug = self.class.generated_slug(self.slug)
  end
  private :normalize_slug
  
  def full_slug
    @full_slug ||= begin
      full_slug = []
      category = self
      begin; full_slug.unshift(category.slug); end while category = category.parent
      full_slug
    end
  end

  def link(user = self.journal.user)
    if meth = Thread.current['alt_category_url_method']
      meth.call(self)
    else
      journal_category_archive_url(self, :user => user, :host => Codexed.base_domain)
    end
  end
  
  #=== Finders ===
  
  def self.find_by_full_slug(full_slug)
    category = nil
    for slug in full_slug
      category = find_by_slug_and_parent_id(slug, category ? category.id : nil)
      return nil unless category
    end
    category
  end
end
