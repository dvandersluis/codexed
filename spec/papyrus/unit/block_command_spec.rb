require File.dirname(__FILE__)+'/test_helper'

class SomeBlockCommand < Papyrus::BlockCommand
  #def active_block; NodeList.new; end
end

describe Papyrus::BlockCommand do

  it "should include ContextItem" do
    Papyrus::BlockCommand.ancestors.should include(ContextItem)
  end
  
  it_should_delegate :add, :<<, :to => :active_block, :with => Node.new, :from => SomeBlockCommand.new("", NodeList.new, [])
  
  describe '.new' do
    it "should raise a TypeError if called directly" do
      lambda { BlockCommand.new }.should raise_error(TypeError)
    end
  end
  
  describe '.active_block' do
    it "should raise a NotImplementedError if called directly" do
      lambda { SomeBlockCommand.new("", NodeList.new, []).active_block }.should raise_error(NotImplementedError)
    end
  end

end