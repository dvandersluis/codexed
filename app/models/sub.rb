# == Schema Information
# Schema version: 20080712010244
#
# Table name: subs
#
#  id         :integer(11)     not null, primary key
#  journal_id :integer(11)     not null
#  name       :string(20)      default(""), not null
#  value      :string(255)     default(""), not null
#

class Sub < ActiveRecord::Base
  belongs_to :journal

  before_validation :downcase_name

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :journal_id, :message => :already_used
  validates_format_of :name, :with => /^[\w-]+$/, :message => :bad_chars
  
  before_save :downcase_name

  def <=>(other)
    self.name <=> other.name
  end

private
  def downcase_name
    name.downcase!
  end
end
