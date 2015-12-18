require File.dirname(__FILE__)+'/test_helper'

describe Sub do
  
  describe '#<=>' do
    it "should compare the sub's name with the given sub's name" do
      sub1 = Sub.new(:name => 'foo')
      sub2 = Sub.new(:name => 'bar')
      (sub1 <=> sub2).should == ('foo' <=> 'bar')
    end
  end
  
  describe '#downcase_name' do
    it "should convert the sub's name to lowercase" do
      sub = Sub.new(:name => 'FooBar')
      sub.send :downcase_name
      sub.name.should == 'foobar'
    end
  end
  
end