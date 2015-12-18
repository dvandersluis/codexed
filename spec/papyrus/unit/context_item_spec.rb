require File.dirname(__FILE__)+'/test_helper'

module Papyrus
  class ContextItemWrapper
    include ContextItem
    attr_reader :parent
  end
end

describe Papyrus::ContextItem do
  
  before :each do
    @ci = ContextItemWrapper.new
    @ci.ivs "@vars", {}
  end
  
  describe "when included" do
    it 'should define attribute accessors for @object' do
      methods = ContextItemWrapper.instance_methods
      methods.should include("object")
      methods.should include("object=")
    end
    it 'should define #[]= (as an alias for #set)' do
      ContextItemWrapper.instance_methods.should include('[]=')
    end
    it 'should define #[] (as an alias for #get)' do
      ContextItemWrapper.instance_methods.should include('[]')
    end
    it 'should define #include? (as an alias for #has_key?)' do
      ContextItemWrapper.instance_methods.should include('include?')
    end
  end
  
  it_should_delegate(:has_key?, :include?, :to => :vars, :from => ContextItemWrapper.new)
  
  describe '#get' do
    it "should not resolve a variable that starts with a number" do
      @ci.ivs "@vars", "342skfdlf" => "foo"
      lambda { @ci.get("342skfdlf") }.should raise_error(UnknownVariableError)
    end
    it 'should stringify the given variable name before using it' do
      @ci.stub_methods(:get_primary_part => nil)
      @ci.get(:foo)
      @ci.should have_received(:get_primary_part).with("foo", "foo")
    end
    it "should get the primary part of the variable and then stop short if there's only one part" do
      @ci.stub_method(:get_primary_part => "some value")
      value = @ci.get("foo")
      value.should == "some value"
      @ci.should_not have_received(:get_secondary_part)
    end
    it "should resolve a multi-part variable" do
      @ci.stub_methods(:get_primary_part => {'bar' => 'baz'}, :get_secondary_part => 'baz')
      value = @ci.get("foo.bar")
      value.should == "baz"
      @ci.should have_received(:get_secondary_part).with("foo.bar", "bar", 'bar' => 'baz')
    end
    it "should not continue resolving a multi-part variable if it can't find the first part" do
      @ci.stub_methods(:get_primary_part => nil)
      @ci.track_method(:get_secondary_part)
      @ci.get("foo.bar")
      @ci.should_not have_received(:get_secondary_part)
    end
  end

  describe '#set' do
    it "should store the given value in @vars as the given key, stringifying and downcasing the key beforehand" do
      @ci.ivs "@vars", {}
      @ci.set(:goUlAsh, "bar")
      @ci.ivg("@vars")["goulash"].should == "bar"
    end
  end
  
  describe '#delete' do
    it "should remove the given key from @vars" do
      @ci.ivs "@vars", {"foo" => "bar"}
      @ci.delete("foo")
      @ci.ivg("@vars").should == {}
    end
  end
  
  describe '#vars' do
    it "should set @vars to a new hash and return it if @vars hasn't been defined yet" do
      @ci.vars
      @ci.vars.should == {}
    end
    it "should return @vars if it's defined" do
      @ci.ivs "@vars", {"foo" => "bar"}
      @ci.vars.should == {"foo" => "bar"}
    end
  end
  
  describe '#vars=' do
    it "should replace @vars with the given hash" do
      @ci.vars = {"foo" => "bar"}
      @ci.ivg("@vars").should == {"foo" => "bar"}
    end
    it "should stringify the given hash before storing it" do
      @ci.vars = {:foo => "bar", :baz => "quux"}
      @ci.ivg("@vars").should == {"foo" => "bar", "baz" => "quux"}
    end
  end
  
  describe '#parser' do
    it "should return the parser of the parent node if this context has a parent" do
      @ci.ivs "@parent", Object.stub_instance(:parser => :parser)
      @ci.parser.should == :parser
    end
    it "should return nil if this context doesn't have a parent" do
      @ci.ivs "@parent", nil
      @ci.parser.should == nil
    end
  end
  
  describe '#true?' do
    it "should return true when the given variable resolves to true" do
      @ci.stub_method(:get => true)
      @ci.true?("").should == true
    end
    it "should return true when the given variable resolves to a true-ish value" do
      @ci.stub_method(:get => "foo")
      @ci.true?("").should == true
    end
    it "should return false when the given variable resolves to false" do
      @ci.stub_method(:get => false)
      @ci.true?("").should == false
    end
    it "should return false when the given variable resolves to nil" do
      @ci.stub_method(:get => nil)
      @ci.true?("").should == false
    end
  end
  
  #---
  
  describe '#get_primary_part' do
    it "should return the value of @vars' key that matches this part" do
      @ci.ivs "@vars", {"foo" => "bar"}
      @ci.send(:get_primary_part, "foo", "foo").should == "bar"
    end
    it "should return the value of @object's key that matches this part, if @object is a hash" do
      @ci.ivs "@object", {"foo" => "bar"}
      @ci.send(:get_primary_part, "foo", "foo").should == "bar"
    end
    it "should return the value of @object's key that matches this part (as a symbol), if @object is a hash" do
      @ci.ivs "@object", {:foo => "bar"}
      @ci.send(:get_primary_part, "foo", "foo").should == "bar"
    end
    it "should return the value of @object's method that matches this part" do
      mock = Object.stub_instance(:foo => "bar")
      @ci.ivs "@object", mock
      value = @ci.send(:get_primary_part, "foo", "foo")
      value.should == "bar"
      mock.should have_received(:foo)
    end
    it "should try to resolve this part in the parent context as a last resort" do
      parent = Object.stub_instance(:get => "bar")
      @ci.ivs "@parent", parent
      value = @ci.send(:get_primary_part, "foo", "foo")
      parent.should have_received(:get).with("foo")
      value.should == "bar"
    end
    it "should raise UnknownVariableError if this part could not be resolved" do
      lambda { @ci.send(:get_primary_part, "foo", "foo") }.should raise_error(UnknownVariableError)
    end
  end
  
  describe '#get_secondary_part' do
    it "should return the value of @vars' key that matches this part" do
      @ci.ivs "@vars", {"foo.bar" => "baz"}
      @ci.send(:get_secondary_part, "foo.bar", "bar", nil).should == "baz"
    end
    describe "when value-so-far is not nil" do
      it "should treat this part as a key in the value-so-far, if it's a hash" do
        @ci.send(:get_secondary_part, "foo.bar", "bar", {"bar" => "baz"}).should == "baz"
      end
      it "should treat this part as an index of the value-so-far, if it's an array" do
        @ci.send(:get_secondary_part, "foo.1", "1", [ "quux", "baz" ]).should == "baz"
      end
      it "should return the value of the value-so-far's method that matches this part" do
        mock = Object.stub_instance(:bar => 'baz')
        @ci.send(:get_secondary_part, "foo.bar", "bar", mock).should == "baz"
      end
      it "should raise UnknownVariableError if value-so-far has no method that matches this part" do
        mock = Object.stub_instance(:joe => 'bloe')
        lambda { @ci.send(:get_secondary_part, "foo.bar", "bar", mock) }.should raise_error(UnknownVariableError)
      end
    end
    it "should raise UnknownVariableError if this part could not be resolved" do
      lambda { @ci.send(:get_secondary_part, "foo.bar", "foo", nil) }.should raise_error(UnknownVariableError)
    end
  end
  
end