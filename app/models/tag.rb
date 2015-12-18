class Tag < ActiveRecord::Base
  include ActionController::UrlWriter
  include UrlHelpersMixin
  
  before_validation :downcase!

  validates_uniqueness_of :name
  validates_presence_of :name, :message => :blank 
  validates_length_of :name, :maximum => 200, :allow_nil => true
  validates_format_of :name, :not => /(^\.{1,2}($|\/))|,/

  has_many :post_tags
  has_many :posts, :through => :post_tags
  
  #===
  
  def self.find_by_name(name)
    # Uses LIKE for case insensitivity
    find(:first, :conditions => ["name = LOWER(?)", name])
  end

  def self.popular_tags(limit = nil)
    query = "SELECT t.name
      FROM tags AS t
      LEFT JOIN post_tags AS pt
        ON pt.tag_id = t.id
      GROUP BY t.id
      ORDER BY COUNT(pt.tag_id) DESC"
    query << "\nLIMIT #{limit.to_i}" if !limit.nil? and limit.to_i > 0

    connection.select_values(query).sort
  end
  
  def to_s
    name
  end

  def link(user)
    if meth = Thread.current['alt_tag_url_method']
      meth.call(self)
    else
      journal_tag_archive_url(self, :user => user, :host => Codexed.base_domain)
    end
  end

private
  def downcase!
    name.downcase!
  end
end
