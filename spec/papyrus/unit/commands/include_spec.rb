require File.dirname(__FILE__)+'/../test_helper'

describe Papyrus::Commands::Include do
  
  it "should be an InsertionSub" do
    Commands::Include.ancestors.should include(InsertionSub)
  end
  
  before do
    @include = Commands::Include.new("", NodeList.new, [])
  end
  
  describe '.new' do
    it "should not set @template_name" do
      @include.ivg("@template_name").should == nil
    end
  end
  
  describe '#get_template_source' do
    it "should raise a NotImplementedError by default" do
      lambda { @include.get_template_source }.should raise_error(NotImplementedError)
    end
  end
  
  describe '#evaluate' do
    before do
      @include.stub_methods(:get_template_source => "The template content", :parse_and_insert_into_parent => nil)
    end
    it "should evaluate @args and set @evaluated_args to that" do
      @include.ivs "@args", stub(:to_a => %w(foo bar baz))
      @include.evaluate
      @include.ivg("@evaluated_args").should == %w(foo bar baz)
    end
    it "should set @template_name to the first argument (after evaluating the args)" do
      @include.ivs "@args", stub(:to_a => %w(foo bar baz))
      @include.evaluate
      @include.ivg("@template_name").should == "foo"
    end
    it "should raise a Papyrus::ArgumentError if a template name was not supplied" do
      @include.ivs "@args", stub(:to_a => [])
      lambda { @include.evaluate }.should raise_error(Papyrus::ArgumentError)
    end
    it "should grab the template content, run it through the parser, and insert the nodes into the current document" do
      @include.ivs "@args", stub(:to_a => %w(foo bar baz))
      @include.evaluate
      @include.should have_received(:parse_and_insert_into_parent).with("The template content")
    end
    it "should return the template content after inserting it in the current document" do
      @include.ivs "@args", stub(:to_a => %w(foo bar baz))
      @include.evaluate.should == "The template content"
    end
  end
  
end