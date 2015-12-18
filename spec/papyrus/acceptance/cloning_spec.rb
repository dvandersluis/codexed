require File.dirname(__FILE__)+'/test_helper'

describe "When cloning template nodes" do
  
  it "all the parent links of the cloned nodes should be pointed to other cloned nodes" do
    args3 = NodeList.new
    sub3 = Sub.new("baz", args3, [])
    args2 = NodeList.new([sub3])
    sub2 = Sub.new("bar", args2, [])
    text1 = Text.new("zing")
    args1 = NodeList.new([sub2, text1])
    sub1 = Sub.new("foo", args1, [])
    # establish what we already know
    args1.parent.should equal(sub1)
    text1.parent.should equal(args1)
    sub2.parent.should equal(args1)
    args2.parent.should equal(sub2)
    sub3.parent.should equal(args2)
    args3.parent.should equal(sub3)
    # now let's test the magic
    sub1p = sub1.clone
    args1p = sub1p.args
    args1p.parent.should equal(sub1p)
    sub2p, text1p = args1p.nodes
    sub2p.parent.should equal(args1p)
    text1p.parent.should equal(args1p)
    args2p = sub2p.args
    args2p.parent.should equal(sub2p)
    sub3p, = args2p.nodes
    sub3p.parent.should equal(args2p)
    args3p = sub3p.args
    args3p.parent.should equal(sub3p)
  end
  
end