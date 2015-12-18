class UserFavorite < ActiveRecord::Base
  belongs_to :user
  belongs_to :journal

  validates_uniqueness_of :journal_id, :scope => :user_id, :message => :exists
  #validate :cannot_add_self

  before_save :set_display_name

  attr_reader :age, :order
  attr_writer :age, :order

  # redundant?
  
  def user
    User.find(self.user_id)
  end
  
  def journal
    Journal.find_by_id(self.journal_id)
  end

private
  def cannot_add_self
    if self.journal_id == self.user_id
      errors.add_to_base(:no_self_add)
    end
  end

  def set_display_name
    self.display_name = self.journal.user.username
  end
end
