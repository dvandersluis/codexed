require File.dirname(__FILE__)+'/test_helper'

class Inserter
  include InsertionSub
end

describe Papyrus::InsertionSub do
  
  before do
    @inserter = Inserter.new
  end
  
  describe '#parse_and_insert_into_parent' do
    def setup
      # good grief...
      @parent = Object.stub_instance(:expand_current => nil)
      @new_doc = Object.new
      @inserter.stub_methods(
        :template => Object.stub_instance(:clone_with => Object.stub_instance(:analyze => @new_doc)),
        :parent => @parent
      )
    end
    it "should return an empty string if the given content is blank" do
      setup
      lambda {
        @inserter.parse_and_insert_into_parent("").should == ""
      }.should_not raise_error(RedoEvaluation)
      @inserter.should_not have_received(:clone_with)
      @parent.should_not have_received(:expand_current)
    end
    it "should run the content through a new Parser instance, insert the nodes into the current document, and raise RedoEvaluation at the end" do
      setup
      nodes = [ Sub.new("foo", NodeList.new, TokenList.new) ]
      @new_doc.stub_methods(:nodes => nodes)
      lambda { @inserter.parse_and_insert_into_parent("something") }.should raise_error(RedoEvaluation)
      @parent.should have_received(:expand_current).with(nodes, NodeList)
    end
    it "should insert a BodyNodeList into the document if this insertion sub is a [body] variable" do
      @inserter = Variable.new("body", [])
      setup
      nodes = [ Sub.new("foo", NodeList.new, TokenList.new) ]
      @new_doc.stub_methods(:nodes => nodes)
      begin; @inserter.parse_and_insert_into_parent("something"); rescue RedoEvaluation; end
      @parent.should have_received(:expand_current).with(nodes, BodyNodeList)
    end
    it "should parse the given content and return its evaluation immediately if it doesn't have any subs in it" do
      setup
      @new_doc.stub_methods(:nodes => [ Text.new("foo") ], :evaluate => "the result")
      lambda {
        result = @inserter.parse_and_insert_into_parent("something")
        @parent.should_not have_received(:expand_current)
        result.should == "the result"
      }.should_not raise_error(RedoEvaluation)
    end
  end
  
end