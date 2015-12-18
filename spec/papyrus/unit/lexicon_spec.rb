require File.dirname(__FILE__)+'/test_helper'

module TestModule
  class Foo; end
  class Bar; end
end

describe Papyrus::Lexicon do
  
  # probably a better way to do this
  before :each do
    Papyrus::Lexicon.cvs "@@commands", {}
    Papyrus::Lexicon.cvs "@@extensions", []
  end
  after :each do
    Papyrus::Lexicon.cvs "@@commands", {}
    Papyrus::Lexicon.cvs "@@extensions", []
  end
  
  describe ".add_commands" do
    it "should add the given command to the global commands hash" do
      mod = Module.new
      Papyrus::Lexicon.add_command "foo", mod
      Papyrus::Lexicon.cvg("@@commands").should == { "foo" => mod }
    end
  end
  
  describe '.extend_lexicon' do
    it "should read the classes contained in the given module and add them to the lexicon as commands" do
      Papyrus::Lexicon.extend_lexicon(TestModule)
      Papyrus::Lexicon.commands.should == { "foo" => TestModule::Foo, "bar" => TestModule::Bar }
    end
    it "should do nothing if the lexicon has already been extended with the given class" do
      Papyrus::Lexicon.track_methods(:add_command)
      Papyrus::Lexicon.extend_lexicon(TestModule)
      Papyrus::Lexicon.extend_lexicon(TestModule)
      Papyrus::Lexicon.extensions.should include(TestModule)
      Papyrus::Lexicon.should have_received(:add_command).twice  # for the two commands
    end
  end
  
end