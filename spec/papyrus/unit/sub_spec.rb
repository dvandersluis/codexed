require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::Sub do
  
  before :each do
    @sub = Sub.new("", NodeList.new, [])
  end
  
  describe '.new' do
    it "should set @name to the given name, case-insensitively" do
      Sub.new("trOgdoR", NodeList.new, []).ivg("@name").should == "trogdor"
    end
    it "should set @args to the given args" do
      nodes = NodeList.new
      Sub.new("", nodes, []).ivg("@args").should == nodes
    end
    it "should set the parent of the NodeList to this Sub" do
      nodes = NodeList.new
      sub = Sub.new("", nodes, [])
      nodes.parent.should == sub
    end
    it "should set @raw_tokens to the given raw tokens" do
      tokens = TokenList.new
      Sub.new("", NodeList.new, tokens).ivg("@raw_tokens").should == tokens
    end
  end
  
  describe '#dup or #clone (via #initialize_copy)' do
    it "should create a copy of the original sub's args" do
      args = NodeList.new([ Text.new("foo"), Text.new("bar") ])
      sub = Sub.new("", args, [])
      sub2 = sub.clone
      
      sub2.args.should_not equal(sub.args)
      sub2.args << Text.new("baz")
      sub.args.should_not include(Text.new("baz"))
    end
    it "should create a copy of the original sub's raw tokens" do
      raw_tokens = TokenList[ "foo", "bar" ]
      sub = Sub.new("", NodeList.new, raw_tokens)
      sub2 = sub.clone
      
      sub2.raw_tokens.should_not equal(sub.raw_tokens)
      sub2.raw_tokens << Token::Text.new("zing")
      sub.raw_tokens.should_not include(Token::Text.new("zing"))
    end
  end
  
  #---
  
  describe '#evaluate?' do
    it "should return false if any of this sub's ancestors are in the template's shielded commands list" do
      @sub.stub_methods(
        :template => stub(:shielded_commands => %w(foo)),
        "parent.parent.parent" => Sub.new("foo", NodeList.new, [])
      )
      @sub.evaluate?.should == false
    end
    it "should return true if none of this sub's ancestors are in the template's shielded commands list" do
      sub = Sub.new("foo", NodeList.new, [])
      @sub.stub_methods(
        "template.shielded_commands" => [],
        "parent.parent.parent" => sub
      )
      @sub.evaluate?.should == true
    end
    it "should return true if the sub doesn't have a parent" do
      @sub.stub_methods("template.shielded_commands" => %w(foo))
      @sub.evaluate?.should == true
    end
  end
  
  describe '#raw_sub' do
    it "should return the stringified version of the raw TokenList" do
      sub = Sub.new("", NodeList.new, %w([ foo ]))
      sub.raw_sub.should == "[foo]"
    end
  end
  
  describe '#insertion_parent' do
    it "should return nil if this sub doesn't have an old_parent" do
      @sub.stub_methods(:old_parent => nil)
      @sub.insertion_parent.should == nil
    end
    it "should return the sub that this sub replaced in the node tree, if this sub has an old_parent" do
      @sub.stub_methods(:old_parent => 
        stub(:template => 
          stub(:parent => 
            stub(:wrapper => :wrapper)
          )
        )
      )
      @sub.insertion_parent.should == :wrapper
    end
  end
  
  describe '#insertion_doppelganger' do
    before do
      @sub = Sub.new("foo", NodeList.new, [])
    end
    it "should return nil if this sub doesn't have an insertion_parent" do
      @sub.stub_methods(:insertion_parent => nil)
      @sub.insertion_doppelganger.should == nil
    end
    it "should return nil if this sub has an insertion_parent but it isn't the same as this sub" do
      @sub.stub_methods(:insertion_parent => Sub.new("bar", NodeList.new, []))
      @sub.insertion_doppelganger.should == nil
    end
    it "should not return a sub that is the same object as this sub" do
      @sub.stub_methods(:insertion_parent => @sub)
      @sub.insertion_doppelganger.should_not equal(@sub)
    end
    it "should return the sub that has the same name and args as this sub, directly backward in an older timeline" do
      sub = Sub.new("bar", NodeList.new([ Text.new("booboo") ]), [])
      sub2 = Sub.new("foo", NodeList.new, [])
      sub.stub_methods(:insertion_parent => sub2)
      @sub.stub_methods(:insertion_parent => sub)
      @sub.insertion_doppelganger.should equal(sub2)
    end
    it "should return the sub that has the same name and args as this sub, in an older timeline, but not-so-directly backward" do
      sub4 = Sub.new("foo", NodeList.new, [])
      sub3 = Sub.new("baz", NodeList.new, []) ; sub3.stub_methods(
        :insertion_parent => sub4,
        :old_parent => nil,
        :parent => nil
      )
      list2 = stub(
        :old_parent => nil,
        :parent => sub3
      )
      sub2 = Sub.new("bar", NodeList.new, []) ; sub2.stub_methods(
        :insertion_parent => nil,
        :old_parent => nil,
        :parent => list2
      )
      list1 = stub(
        :old_parent => nil,
        :parent => sub2
      )
      @sub.stub_methods(
        :insertion_parent => nil,
        :old_parent => nil,
        :parent => list1
      )
      @sub.insertion_doppelganger.should equal(sub4)
    end
  end
  
  describe '#==' do
    it "should return false if the given object is not a Sub" do
      sub = Sub.new("foo", NodeList.new, [])
      other = String.new
      sub.should_not == other
    end
    it "should return false if the given object is a Sub, but doesn't have the same name as this sub" do
      sub1 = Sub.new("", NodeList.new, [])
      sub1.ivs "@name", "foo"
      sub2 = Sub.new("", NodeList.new, [])
      sub2.ivs "@name", "bar"
      sub1.should_not == sub2
    end
    it "should return false if the given object is a Sub and has the same name, but not the same args" do
      sub1 = Sub.new("", NodeList.new, [])
      sub1.ivs "@name", "foo"
      sub1.ivs "@args", NodeList.new([ Text.new("bar") ])
      sub2 = Sub.new("", NodeList.new, [])
      sub2.ivs "@name", "foo"
      sub2.ivs "@args", NodeList.new([ Text.new("baz") ])
      sub1.should_not == sub2
    end
    it "should return false if the given object is a Sub, has the same name and args, but not raw tokens" do
      sub1 = Sub.new("", NodeList.new, [])
      sub1.ivs "@name", "foo"
      sub1.ivs "@args", NodeList.new([ Text.new("bar") ])
      sub1.ivs "@raw_tokens", ["a"]
      sub2 = Sub.new("", NodeList.new, [])
      sub2.ivs "@name", "foo"
      sub2.ivs "@args", NodeList.new([ Text.new("bar") ])
      sub2.ivs "@raw_tokens", ["b"]
      sub1.should_not == sub2
    end
    it "should return true if the given object is a Sub and has the same name, args, and raw tokens" do
      sub1 = Sub.new("", NodeList.new, [])
      sub1.ivs "@name", "foo"
      sub1.ivs "@args", NodeList.new([ Text.new("bar") ])
      sub1.ivs "@raw_tokens", ["a"]
      sub2 = Sub.new("", NodeList.new, [])
      sub2.ivs "@name", "foo"
      sub2.ivs "@args", NodeList.new([ Text.new("bar") ])
      sub2.ivs "@raw_tokens", ["a"]
      sub1.should == sub2
    end
  end
  
  #---
    
  describe '#command_allowed?' do
    it "should return true if no allowed commands were specified" do
      @sub.stub_methods(:template => Object.stub_instance(:allowed_commands => nil))
      @sub.send(:command_allowed?).should == true
    end
    it "should return true if allowed commands were specified and sub name is in allowed commands" do
      @sub.ivs "@name", "foo"
      @sub.stub_methods(:template => Object.stub_instance(:allowed_commands => ["foo"]))
      @sub.send(:command_allowed?).should == true
    end
    it "should retrn false if allowed commands were specified, but sub name is not in allowed commands" do
      @sub.ivs "@name", "foo"
      @sub.stub_methods(:template => Object.stub_instance(:allowed_commands => []))
      @sub.send(:command_allowed?).should == false
    end
  end
  
  describe '#evaluates_as_variable?' do
    it "should return true if the sub has no arguments" do
      @sub.ivs "@args", NodeList.new
      # poor man's any_instance :(
      Variable.stub_methods :new => (returning Variable.new("foo", []) do |var|
        var.stub_methods(:evaluate => "")
      end)
      @sub.send(:evaluates_as_variable?).should == true
    end
    it "should return nil if the sub has arguments" do
      @sub.ivs "@args", NodeList.new([ Text.new("foo") ])
      @sub.send(:evaluates_as_variable?).should == nil
    end
    it "should return nil if a ParserError is raised while the variable is evaluated" do
      @sub.ivs "@args", NodeList.new
      # poor man's any_instance :(
      Variable.stub_methods :new => (returning Variable.new("foo", []) do |var|
        var.stub_methods_to_raise(:evaluate => ParserError)
      end)
      @sub.send(:evaluates_as_variable?).should == false
    end
    # how do we add a test for setting wrapper?
  end
  
end