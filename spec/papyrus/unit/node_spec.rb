require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::Node do
  
  before :each do 
    @node = Node.new
  end
  
  it_should_delegate :get, :to => :@parent, :from => lambda {
    node = Node.new
    node.parent = Object.new
    node
  }
  
  it_should_delegate :parser, :document, :template, :to => :@parent, :allow_nil => true, :from => lambda {
    node = Node.new
    node.parent = Object.new
    node
  }
  
  describe '#evaluate' do
    it "should raise a NotImplementedError by default" do
      lambda { @node.evaluate }.should raise_error(NotImplementedError)
    end
  end
  
end