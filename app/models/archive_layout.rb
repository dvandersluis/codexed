class ArchiveLayout < ActiveRecord::Base
  module AssocExtensions
    def find_as_post(type_id, vars={})
      journal = proxy_owner
      raise "Invalid archive type" unless ArchiveLayoutType.exists?(type_id)
      if layout = find_by_type_id(type_id)
        returning journal.posts.build do |post|
          # The reason this is not a fake post is because line breaks will not be converted otherwise
          # See Post.process_body for more
          post.title = layout.title
          post.raw_body = layout.content
          post.created_at = Time.now
          post.posted_at = journal.current_entry.andand.posted_at || Time.now
          post.template = layout.template
          post.type_id = "A"
        end
      else
        # pull from fake post
        # I know this is kind of scattered, I'll figure out a better way to do this
        name = (type_id == "complete_archive") ? "archive" : type_id
        post = journal.posts.find_fake_by_name(name, vars)
        post.body = Template.run_through_erb(post.raw_body, 'template' => ActionView::Base.new)
        post.type_id = "A"
        post
      end
    end
  end
  
  # Rename Rails' default inheritance column ("type") so we can use it for other things
  self.inheritance_column = "klass" if method_defined?(:inheritance_column)  
  
  belongs_to :journal
  belongs_to :type, :class_name => "ArchiveLayoutType"
  belongs_to :template
  
  validates_presence_of :title
  validates_uniqueness_of :type_id, :scope => :journal_id
  
  #---
  
  def to_param; type_id; end
  
  alias_method :assigned_template, :template
  def template
    # If somehow the assigned template doesn't belong to this journal, use the fallback
    (self.assigned_template if self.assigned_template.andand.journal == self.journal) || self.journal.default_template || self.journal.fallback_template
  end
  
end
