require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::Variable do
  
  before :each do 
    @var = Variable.new("", [])
  end
  
  it "should be an InsertionSub" do
    Variable.ancestors.should include(InsertionSub)
  end
  
  describe '.new' do
    it "should store the given name, case-insensitively" do
      Variable.new("FooBaR", []).ivg("@name").should == "foobar"
    end
    it "should store the raw representation of the variable" do
      Variable.new("", :tokens).ivg("@raw_tokens").should == :tokens
    end
  end
  
  describe '#evaluate' do
    before do
      # stub this so it returns whatever's passed to it
      @var.stub_method(:parse_and_insert_into_parent) {|arg| arg }
    end
    it "should run the value of the variable through the parser and inject the nodes into the current document" do
      @var.ivs "@parent", Object.stub_instance(:get => "value")
      @var.evaluate
      @var.should have_received(:parse_and_insert_into_parent).with("value")
    end
    it "should return the value of the variable, if it exists" do
      @var.ivs "@parent", Object.stub_instance(:get => "some value")
      @var.evaluate.should == "some value"
    end
    it "should return an empty string if the variable exists but has a nil value" do
      @var.ivs "@parent", Object.stub_instance(:get => false)
      @var.evaluate.should == ""
      @var.ivs "@parent", Object.stub_instance(:get => nil)
      @var.evaluate.should == ""
    end
    it "should stringify the value of the variable before returning it" do
      @var.ivs "@parent", Object.stub_instance(:get => 2)
      @var.evaluate.should == "2"
      @var.ivs "@parent", Object.stub_instance(:get => true)
      @var.evaluate.should == "true"
    end
    it "should return a BodyString if the variable is a [body] variable" do
      @var.ivs "@name" => "body", "@parent" => Object.stub_instance(:get => "whatever")
      @var.evaluate.should be_a(BodyString)
    end
    it "should return the raw sub if the variable doesn't exist" do
      @var.stub_method(:raw_sub => "[foo]")
      @var.ivs "@parent", (returning(Object.new) do |parent|
        parent.stub_methods_to_raise(:get => UnknownVariableError)
      end)
      @var.evaluate.should == "[foo]"
    end
  end
  
  describe '#==' do
    it "should return true if the given object is a Variable and has the same name" do
      var = Variable.new("", [])
      var.ivs "@name", "foo"
      var2 = Variable.new("", [])
      var2.ivs "@name", "foo"
      var.should == var2
    end
    it "should return false if the given object is not a Variable" do
      var = Variable.new("foo", [])
      other = String.new
      var.should_not == other
    end
    it "should return false if the given object is a Variable, but does not have the same name" do
      var = Variable.new("", [])
      var.ivs "@name", "foo"
      var2 = Variable.new("", [])
      var2.ivs "@name", "bar"
      var.should_not == var2
    end
  end
  
end