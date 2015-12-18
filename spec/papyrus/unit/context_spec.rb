require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::Context do
  
  describe 'Context.new' do
    it "should set @parent to the given parent node" do
      parent = Object.new
      Context.new(parent).ivg("@parent").should == parent
    end
    it "should set @object to the given object" do
      object = Object.new
      Context.new(nil, object).ivg("@object").should == object
    end
    it "should set @vars to an empty hash" do
      Context.new.ivg("@vars").should == {}
    end
  end
  
  describe 'Context.construct_from' do
    it "should return a new Context whose vars are set to the given hash" do
      hash = { 'foo' => 'bar' }
      cxt = Context.construct_from(hash)
      cxt.should be_a_kind_of(Context)
      cxt.vars.should == hash
    end
  end
  
end