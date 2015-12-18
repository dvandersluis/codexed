require File.dirname(__FILE__)+'/test_helper'

describe Papyrus do
  
  # This probably won't work until we get real Commands going
  #it "should be able to refer to a variable in a parent context"
  #  template = Template.new(nil)
  #  if_cmd = Commands::If.new(template, "if", [])
  #  if_cmd.vars = { 'foo' => 'bar' }
  #  if_cmd2 = Commands::If.new(if_cmd, "if", [])
  #  if_cmd << if_cmd2
  #  if_cmd2.active_block.get('foo').should == "bar"
  #end
  
end