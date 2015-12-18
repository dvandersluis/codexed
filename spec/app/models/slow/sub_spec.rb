require File.dirname(__FILE__)+'/test_helper'

describe Sub, :type => :model do
  
  before :all do
    create_sub!
  end
  
  should_belong_to :journal
  
  should_validate_presence_of :name, :message => l(:validation_blank)
  it "should validate uniqueness of name" do
    new_sub.should validate_uniqueness_of(:name, :scope => :journal_id, :message => l(:validation_sub_already_used))
  end
  should_validate_format_of :name, "abc_123", "123abc", "éclaire", "e-mail", "fraü heimlich"
  should_not_validate_format_of :name, 's@uirrely#$%Q', "<html>", "[foo]", :message => l(:validation_sub_bad_chars)
  
end

def new_sub
  Sub.new(:name => "foo", :value => "bar", :journal_id => 1)
end
def create_sub!
  new_sub.save!
end
