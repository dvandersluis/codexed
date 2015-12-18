require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::NodeList do
  
  before :each do
    @list = NodeList.new
  end
  
  it_should_delegate :length, :size, :first, :last, :empty?, :shift, :clear, :include?, :delete, :to => :@nodes, :from => NodeList.new
  it_should_delegate :map, :map!, :each, :with => [ Proc.new {|x| } ], :to => :@nodes, :from => NodeList.new
  
  describe '.new' do
    it "should set @nodes to an empty list by default" do
      @list.ivg("@nodes").should == []
    end
    it "should set @nodes to the given value" do
      NodeList.new([ Text.new("foo"), Text.new("bar") ]).ivg("@nodes").should == [ Text.new("foo"), Text.new("bar") ]
    end
    it "if a NodeList is given should set @nodes to its nodes (not the NodeList itself)" do
      inner = NodeList.new([ Text.new("foo") ])
      NodeList.new(inner).ivg("@nodes").should == [ Text.new("foo") ]
    end
    it "should ensure that all the top-level nodes have this NodeList as its parent" do
      text1 = Text.new("foo"); text1.parent = :joe
      text2 = Text.new("bar"); text2.parent = :mark
      list = NodeList.new([ text1, text2 ])
      list.nodes.each {|node| node.parent.should == list }
    end
  end
  
  describe '#initialize_copy' do
    it "should make a copy of the @nodes array, making sure to also make copies of any inner NodeLists" do
      foo, sublist, quux = nodes = [
        Text.new("foo"),
        NodeList.new([ Text.new("bar"), Text.new("baz") ]),
        Text.new("quux")
      ]
      list = NodeList.new(nodes)
      list2 = list.clone
      foo2, sublist2, quux2 = list2.nodes
      
      foo2.should_not equal(foo)
      quux2.should_not equal(quux)
      sublist2.should_not equal(sublist)
      sublist2 << Text.new("zing")
      sublist.should_not include(Text.new("zing"))
    end
  end
  
  %w(add <<).each do |meth|
    describe "##{meth}" do
      it "should do nothing if given nil" do
        @list.send(meth, nil)
        @list.ivg("@nodes").should be_empty
      end
      it "should raise a TypeError if given something other than a Node" do
        lambda { NodeList.new.send(meth, "not a command") }.should raise_error(TypeError)
      end
      it "should add the given Node to @nodes" do
        node = Node.new
        @list.send(meth, node)
        @list.ivg("@nodes").should include(node)
      end
      it "should set the parent of the given node to the NodeList" do
        cmd = Command.new("", NodeList.new, nil)
        @list.send(meth, cmd)
        cmd.parent.should == @list
      end
    end
  end
  
  describe '#evaluate' do
    describe "within NodeList" do
      it "should take #evaluated_nodes and join consecutive strings into a string" do
        @list.stub_methods(:evaluated_nodes => %w(foo bar baz))
        @list.evaluate.should == ["foobarbaz"]
      end
      it "should add BodyStrings straight to the returned array as separate items" do
        @list.stub_methods(:evaluated_nodes => ["foo", "bar", BodyString.new("baz"), "zing", "zang"])
        @list.evaluate.should == ["foobar", BodyString.new("baz"), "zingzang"]
      end
      it "should add SeparateStrings to the returned array as separate items, but casting them to strings first" do
        @list.stub_methods(:evaluated_nodes => ["foo", "bar", SeparateString.new("baz"), "zing", "zang"])
        @list.evaluate.should == ["foobar", "baz", "zingzang"]
      end
    end
    describe "within BodyNodeList" do
      it "should take strings that aren't already marked as BodyStrings or SeparateStrings and add them as BodyStrings" do
        list = BodyNodeList.new
        list.stub_methods(:evaluated_nodes => ["foo", "bar", "baz" ])
        list.evaluate.should == [BodyString.new("foobarbaz")]
      end
      it "should still add strings that are marked as BodyStrings or SeparateStrings separately, though" do
        list = BodyNodeList.new
        list.stub_methods(:evaluated_nodes => ["foo", "bar", BodyString.new("baz"), "zingaling", "frimfrou", SeparateString.new("tenacious d") ])
        list.evaluate.should == [BodyString.new("foobar"), BodyString.new("baz"), BodyString.new("zingalingfrimfrou"), "tenacious d"]
      end
    end
  end
  
  describe '#to_a' do
    it "should simply call #evaluated_nodes" do
      @list.stub_methods(:evaluated_nodes => nil)
      @list.to_a
      @list.should have_received(:evaluated_nodes)
    end
  end
  
  describe '#expand_current' do
    def text_nodes(*args)
      args.map {|x| Text.new(x) }
    end
    before do
      @list.ivs "@pos", 1
      @list.ivs "@nodes", text_nodes("foo","bar","baz")
    end
    it "should replace the node at the current position with the given nodes" do
      nodes = text_nodes("zing","zang")
      @list.expand_current(nodes, NodeList)
      @list.nodes.should == [ Text.new("foo"), NodeList.new(nodes), Text.new("baz") ]
    end
    it "the new node list should be a child of this node list" do
      nodes = text_nodes("zing","zang")
      @list.expand_current(nodes, NodeList)
      @list.nodes[1].parent.should == @list
    end
    it "should wrap the given nodes in the given node list class" do
      nodes = text_nodes("zing","zang")
      @list.expand_current(nodes, BodyNodeList)
      @list.nodes[1].should be_a(BodyNodeList)
    end
    it "should store the current parent of each node before changing it" do
      text = Text.new("foo")
      list = NodeList.new([ text ])
      text.old_parent.should == nil      
      @list.expand_current(list, NodeList)
      text.old_parent.should equal(list)
    end
  end
  
  describe '#flatten' do
    it "should collapse the NodeList so that it does not contain any inner NodeLists" do
      list = NodeList.new([
        Text.new("foo"),
        NodeList.new([
          Text.new("bar"),
          NodeList.new([
            Text.new("baz")
          ]),
          Text.new("quux")
        ]),
        Text.new("zing")
      ])
      list.flatten.should == NodeList.new(%w(foo bar baz quux zing).map {|str| Text.new(str) })
    end
    it "should assign the new NodeList the same parent as the original NodeList" do
      list = NodeList.new
      list2 = list.flatten
      list2.parent.should == list.parent
    end
  end
    
  describe '#==' do
    it "should return true if the given object is a NodeList and has the same nodes" do
      list = NodeList.new
      list.ivs "@nodes", [ Text.new("one"), Text.new("two"), Text.new("three") ]
      list2 = NodeList.new
      list2.ivs "@nodes", [ Text.new("one"), Text.new("two"), Text.new("three") ]
      list.should == list2
    end
    it "should return false if the given object is not a NodeList" do
      list = NodeList.new
      other = String.new
      list.should_not == other
    end
    it "should return false if the given object is a NodeList but does not have the same nodes" do
      list = NodeList.new
      list.ivs "@nodes", [ Text.new("one"), Text.new("two"), Text.new("three") ]
      list2 = NodeList.new
      list2.ivs "@nodes", [ Text.new("two"), Sub.new("three", NodeList.new, TokenList.new) ]
      list.should_not == list2
    end
  end
  
  #---
  
  describe '#evaluated_nodes' do
    it "should evaluate each node in @nodes and return an array of strings" do
      list = NodeList.new([ Text.new("one"), Text.new("two"), Text.new("three") ])
      list.send(:evaluated_nodes).should == %w(one two three)
    end
    it "should merge the array to which NodeList evaluates with the returned array, instead of appending it" do
      sub = Sub.new("foo", NodeList.new, [])
      sub.stub_methods(:evaluate => SeparateString.new("whatever"))
      list2 = NodeList.new([ Text.new("zing"), sub, Text.new("zang") ])
      list = NodeList.new([ Text.new("one"), list2, Text.new("three") ])
      list.send(:evaluated_nodes).should == %w(one zing whatever zang three)
    end
    it "should back up @nodes to @orig_nodes before evaluating" do
      @list.ivs "@nodes", [ Text.new("foo") ]
      @list.send(:evaluated_nodes)
      @list.ivg("@orig_nodes").should == [ Text.new("foo") ]
    end
    it "should raise an infinite loop message if RedoEvaluation is raised but @pos is never changed" do
      node = Text.new("foo")
      node.stub_methods_to_raise(:evaluate => RedoEvaluation)
      @list.ivs "@nodes", [ node ]
      lambda { @list.send(:evaluated_nodes) }.should raise_error(RuntimeError, "Infinite loop")
    end
    it "should not evaluate a sub if doing so would create an infinite loop" do
      sub = Sub.new("foo", NodeList.new, TokenList.new)
      sub2 = sub.dup
      sub2.stub_methods(:raw_sub => "[stuff]")
      sub.stub_methods(:insertion_doppelganger => sub2)
      @list.ivs "@nodes", [ sub ]
      @list.send(:evaluated_nodes).should == ["[stuff]"]
    end
    it "should crash if any node evaluates to nil" do
      node = stub(:evaluate => nil)
      @list.ivs "@nodes", [ node ]
      lambda { @list.send(:evaluated_nodes) }.should raise_error
    end
  end
  
end