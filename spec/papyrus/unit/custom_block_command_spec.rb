require File.dirname(__FILE__)+'/test_helper'

describe Papyrus::CustomBlockCommand do

  before do
    @bc = CustomBlockCommand.new("", NodeList.new, [])
  end
  
  describe '#evaluate' do
    before :each do
      @bc.stub_methods(:evaluate? => true, :evaluates_as_command_or_variable? => true)
      @bc.ivs "@result", "some result"
    end
    it "should evaluate @args and store the resulting array in @evaluated_args" do
      args = NodeList.new
      args.stub_methods(:to_a => %w(foo bar))
      @bc.ivs "@args", args
      @bc.evaluate
      @bc.ivg("@evaluated_args").should == %w(foo bar)
    end
    it "we should be able to access the original @args after it's been evaluated" do
      args = NodeList.new([ Text.new("foo") ])
      @bc.ivs "@args", args
      @bc.evaluate
      @bc.ivg("@args").should == args
    end
    it "should evaluate @nodes and store the resulting string in @evaluated_nodes" do
      nodes = NodeList.new
      nodes.stub_methods(:evaluate => %w(foo bar))
      @bc.ivs "@nodes", nodes
      @bc.evaluate
      @bc.ivg("@evaluated_nodes").should == "foobar"
    end
    it "we should be able to access the original @nodes after it's been evaluated" do
      nodes = NodeList.new([ Text.new("foo") ])
      @bc.ivs "@nodes", nodes
      @bc.evaluate
      @bc.ivg("@nodes").should == nodes
    end
    describe "if the block command could be evaluated" do
      it "should update the raw tokens with the result of the evaluation" do
        @bc.evaluate
        @bc.ivg("@raw_tokens").should == TokenList[ Token::Text.new("some result") ]
      end
      it "should return the result of the evaluation" do
        @bc.ivs "@result", "some result"
        @bc.evaluate.should == "some result"
      end
    end
    describe "should return the raw sub" do
      it "if the block command shouldn't be evaluated" do
        @bc.stub_methods(:evaluate? => false, :raw_sub => "[foo]")
      end
      it "if the block command can't be evaluated" do
        @bc.stub_methods(:evaluate? => true, :evaluates_as_command_or_variable? => false, :raw_sub => "[foo]")
      end
      after do
        @bc.evaluate.should == "[foo]"
      end
    end
  end
  
  describe '#evaluates_as_command_or_variable?' do
    it "should return true if we can evaluate the block command as a custom command" do
      @bc.stub_methods(:evaluates_as_custom_block_command? => true)
      @bc.send(:evaluates_as_command_or_variable?).should == true
    end
    it "should return true if we can evaluate the block command as a variable" do
      @bc.stub_methods(:evaluates_as_custom_block_command? => false, :evaluates_as_variable? => true)
      @bc.send(:evaluates_as_command_or_variable?).should == true
    end
  end
  
  describe '#evaluates_as_custom_block_command?' do
    describe "if the command is allowed and custom commands was given" do
      before do
        @bc.ivs(
          "@name" => "foo", 
          "@args" => NodeList.new(%w(foo bar baz).map {|x| Text.new(x) }),
          "@evaluated_args" => %w(foo bar baz),
          "@nodes" => NodeList.new(%w(quux blargh spaz).map {|x| Text.new(x) }),
          "@evaluated_nodes" => "quuxblarghspaz"
        )
        @custom_commands = stub("class.has_block_command?" => true, :__call_block_command__ => "the final string")
        @bc.stub_methods(:command_allowed? => true, :template => stub(:custom_commands => @custom_commands))
        @result = @bc.send(:evaluates_as_custom_block_command?)
      end
      it "should call the custom command" do
        @custom_commands.should have_received(:__call_block_command__).with(@bc)
      end
      it "should store the result of the custom command" do
        @bc.ivg("@result").should == "the final string"
      end
      it "should return true" do
        @result.should == true
      end
    end
    describe "should return false" do
      it "if the command is not allowed" do
        @bc.stub_methods(:command_allowed? => false)
      end
      it "if the command is allowed, but the block command doesn't exist" do
        custom_commands = stub("class.has_block_command?" => false)
        @bc.stub_methods(:command_allowed? => true, :template => stub(:custom_commands => custom_commands))
      end
      it "if a ParserError is raised while the command is evaluated" do
        custom_commands = stub("class.has_block_command?" => true)
        custom_commands.stub_methods_to_raise(:__call_block_command__ => ParserError)
        @bc.stub_methods(:command_allowed? => true, :template => stub(:custom_commands => custom_commands))
      end
      after do
        @bc.send(:evaluates_as_custom_block_command?).should == false
      end
    end
  end

end