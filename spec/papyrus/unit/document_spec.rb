require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::Document do
  
  before do
    @doc = Document.new(nil)
  end
  
  it "should be a ContextItem" do
    Document.ancestors.should include(ContextItem)
  end
  
  it_should_delegate :template, :to => :@parser, :from => lambda { Document.new(nil) }
  it_should_delegate :options, :vars, :to => :template, :from => lambda { Document.new(nil) }
  
  describe '.new' do
    it "should set @parser to the given value" do
      Document.new(:parser).ivg("@parser").should == :parser
    end
    it "should initialize the @nodes array using the given NodeList" do
      doc = Document.new(:parser, NodeList.new([ Text.new("foo") ]))
      doc.nodes.should == [ Text.new("foo") ]
    end
  end
  
  describe '#document' do
    it "should just return self" do
      @doc.document.should == @doc
    end
  end
  
end