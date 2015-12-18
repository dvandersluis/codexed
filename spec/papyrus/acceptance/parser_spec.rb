require File.dirname(__FILE__)+'/test_helper'

class CustomCommands < CustomCommandSet
  module InlineCommands
    def frobulate(args)
      "Jim #{args[0]}ed the #{args[1]}"
    end
    
    def tribblize(args)
      args[0].reverse
    end
    
    def sproink(args)
      args.reverse.join(" ")
    end
    
    def zazzimmer(args)
      command = args.shift
      send(command, args)
    end
    
    def picard(args)
      "Jean-Luc"
    end
    
    def enumerate(args)
      (1..5).to_a.join("-")
    end
    
    def quark(args)
      "screw"
    end
  end

  alias_command :quark, :cork

  module BlockCommands
    def reverse_lines(args, inner)
      inner.split(/\n/).reverse.join("\n")
    end
    
    def reverse(args, inner)
      inner.reverse
    end
    
    def straight(args, inner)
      inner
    end
  end
end

class IncludeCommand < Papyrus::Commands::Include
  def get_template_source
    case @template_name
      when "other" then "This is the other template"
      when "another" then "This is another template [include 'yours']"
      when "yours" then "This is yours templates [include 'mine']"
      when "mine" then "This be mine template"
      when "self-referential" then "[include 'self-referential']"
      when "self-referential-within-args" then "[frobulate '[include self-referential-within-args]' bar]"
    end
  end
end
Papyrus::Lexicon.add_command 'include', IncludeCommand

describe "The parser" do
  
  it "should pass text without any subs straight through" do
    Template.render("Here is some text").should == "Here is some text"
  end
  
  describe "when parsing variables" do  
    it "should replace a variable with its value" do
      Template.render("[foo]", :vars => { 'foo' => "Content of variable" }).should == "Content of variable"
    end
    it "should replace a two-part variable with its value" do
      Template.render("[foo.bar]", :vars => { 'foo' => { 'bar' => 'baz' } }).should == "baz"
    end
    it "should not replace a two-part variable if one of the inner values is nil" do
      Template.render("[foo.bar.baz]", :vars => { 'foo' => { 'bar' => nil } }).should == "[foo.bar.baz]"
    end
    it "should replace a variable case-insensitively" do
      one = Template.render("[sOmE_varIable]", :vars => { 'some_variable' => 'dude man' })
      two = Template.render("[some_variable]", :vars => { 'some_variable' => 'dude man' })
      one.should == two
    end
    describe "and replacing subs within variable values" do
      it "should replace a sub within a variable's value" do
        result = Template.render("[foo] [quux]",
          :vars => { 'foo' => '[bar]', 'bar' => 'baz', 'quux' => '[frobulate zing zoom]' },
          :custom_command_class => CustomCommands
        )
        result.should == "baz Jim zinged the zoom"
      end
      it "should replace a sub that is an argument of a sub within a variable's value, even when the parent sub doesn't exist" do
        ret = Template.render("[stuff]", :vars => { 'stuff' => "[foo bar [baz] quux]", 'baz' => 'floog' })
        ret.should == "[foo bar floog quux]"
      end
      describe "and dealing with self-referential variables" do
        it "should not replace a variable if it refers to itself" do
          Template.render("[foo]", :vars => { 'foo' => "[foo]" }).should == "[foo]"
        end
        it "should not replace a variable if a sub eventually evaluates to the same variable" do
          Template.render("[foo]", :vars => { 'foo' => "[bar]", 'bar' => "[baz]", 'baz' => "[foo]" }).should == "[foo]"
        end
        it "should not replace a variable if it evaluates to a sub whose args refer to the variable itself" do
          result = Template.render("[foo]",
            :vars => { "foo" => "[frobulate [foo] bar]" },
            :custom_command_class => CustomCommands
          )
          result.should == "Jim [foo]ed the bar"
        end
        it "should not replace a variable if it evaluates to a sub whose args refer to the variable itself and is surrounded by quotes" do
          result = Template.render("[foo]",
            :vars => { "foo" => '[frobulate "[foo]" bar]' },
            :custom_command_class => CustomCommands
          )
          result.should == "Jim [foo]ed the bar"
        end
        it "should not replace a variable if it evaluates to a sub whose args contain a sub whose args contain the variable" do
          result = Template.render("[foo]",
            :vars => { "foo" => '[frobulate [frobulate [foo] baz] bar]' },
            :custom_command_class => CustomCommands
          )
          result.should == "Jim Jim [foo]ed the bazed the bar"
        end
      end
    end
  end
  
  describe "when parsing backslashed characters" do
    it "should not replace a backslashed sub, eating the backslashes, when the sub is the only thing present" do
      Template.render("\\[foo\\]", :vars => { 'foo' => "Content of variable" }).should == "[foo]"
    end
    it "should not replace backslashed subs, eating the backslashes, when a non-backslashed sub is also present" do
      Template.render("\\[foo\\] bar [baz]", :vars => { 'foo' => "Content of variable", 'baz' => 'blah' }).should == "[foo] bar blah"
    end
    it "should ignore backslashing of anything other than brackets" do
      Template.render("ebb \\/and \\flow").should == "ebb \\/and \\flow"
      Template.render("\\\\italics\\\\").should == "\\\\italics\\\\"
    end
    it "should not replace a backslashed sub within a variable value" do
      Template.render("[foo]", :vars => { 'foo' => "\\[bar\\]" }).should == "[bar]"
    end
  end
  
  describe "when parsing custom commands" do
    def parse(content, options={})
      Template.render(content, { :custom_command_class => CustomCommands }.merge(options))
    end
    it "should replace a custom command with its value" do
      parse("[picard]").should == "Jean-Luc"
    end
    it "should replace a custom command where the name is inside quotes as if the name weren't" do
      parse("['picard']").should == "Jean-Luc"
    end
    it "should replace a custom command with arguments" do
      parse("[tribblize backwards]").should == "sdrawkcab"
    end
    it "should replace nested subs" do
      parse("[frobulate wank [foo]]", :vars => { 'foo' => "Chunky Bacon!!" }).should == "Jim wanked the Chunky Bacon!!"
    end
    it "should replace doubly nested subs" do
      parse('[frobulate wank [tribblize "[foo]"]]', :vars => { 'foo' => "Chunky Bacon!!" }).should == "Jim wanked the !!nocaB yknuhC"
    end
    it "should replace a command only if it's allowed" do
      parse("[picard] [enumerate] [quark]", :allowed_commands => %w(enumerate)).should == "[picard] 1-2-3-4-5 [quark]"
    end
    it "should, when a custom command and variable have the same name, use the value of the custom command over the variable" do
      parse("[quark]", :vars => { "quark" => "jank" }).should == "screw"
    end
    it "should replace a custom command case-insensitively" do
      one = parse("[qUaRk]")
      two = parse("[quark]")
      one.should == two
    end
    it "should replace a command alias" do
      parse("[quark]").should == parse("[cork]")
    end
  end
  
  describe "inside a shielded command" do
    # Note that this just so happens to use custom commands - we could use any type of commands here
    # (or at least we could, if there were other kinds...)
    def parse(content, options={})
      Template.render(content, { :custom_command_class => CustomCommands }.merge(options))
    end
    it "should not replace non-existent subs" do
      parse("[frobulate [foo] [bar]]", :shielded_commands => %w(frobulate)).should == "Jim [foo]ed the [bar]"
    end
    it "should not replace subs one level deep" do
      parse("[frobulate [tribblize erkatz] [sproink dooby brothers]]", :shielded_commands => %w(frobulate)).should == "Jim [tribblize erkatz]ed the [sproink dooby brothers]"
    end
    it "should not replace subs more than one level deep" do
      parse("[frobulate [tribblize erkatz] [sproink [quark] brothers]]", :shielded_commands => %w(frobulate)).should == "Jim [tribblize erkatz]ed the [sproink [quark] brothers]"
    end
  end
  
  describe "when parsing subs with zany quotes" do
    subs = [
      "[']", '["]', "[' foo bar]", "[ '' ('' '' '' ...)]", '[ "quote" ]', '[ "quote"]',
      '[ "one" "two" ]', '[""]', "['']", "[foo'bar]", '["quote" ]', '["quote"]',
      '[ "one""two" ]', '[ "one"-"two" ]', "[ ''' ]", '[ "]', "[ ']", "[]", "[ '' ']"
    ]
    for sub in subs
      it "should not replace #{sub}" do
        Template.render(sub).should == sub
      end
    end
  end

  describe "when parsing subs that have invalid names" do
    subs = [ "[.foo]", "[...]", "[-fdkj]", "[$fooz]", "[(foobar)]" ]
    for sub in subs
      it "should not replace #{sub}" do
        Template.render(sub).should == sub
      end
    end
  end
  
  describe "when parsing non-existent subs" do
    it "should not replace a sub that does not refer to an existent command or variable" do
      Template.render("[foo]").should == "[foo]"
    end
    it "should replace a sub that is an argument of another sub, even when the parent sub doesn't exist" do
      Template.render("[foo bar [baz] quux]", :vars => { 'baz' => 'floog' }).should == "[foo bar floog quux]"
    end
    it "should replace all nested subs that exist and leave alone the subs that don't" do
      ret = Papyrus::Template.render("[foo bar [sproink baz [blargh [spaz] trumble]] quux]", :vars => { 'spaz' => 'trams' }, :custom_command_class => CustomCommands)
      ret.should == "[foo bar [blargh trams trumble] baz quux]"
    end
    it "should replace a sub if it exists, even when a sub inside it doesn't and is not replaced" do
      Papyrus::Template.render("[frobulate [foo] [bar]]", :custom_command_class => CustomCommands).should == "Jim [foo]ed the [bar]"
    end
    it "should not replace a sub if it doesn't exist, and should not replace a sub inside it if it doesn't exist either" do
      Papyrus::Template.render("[ aslkfsdf [bar] asdlf ]").should == "[ aslkfsdf [bar] asdlf ]"
    end
  end
  
  describe "when parsing an [include] command" do
    it "should not replace [include] with no template name" do
      Template.render("[include]").should == "[include]"
    end
    it "should replace [include] with the contents of another template and parse it along with the rest of the template" do
      source = <<EOT
This is some template that's cool and stuff

[include 'other']

And the rest of the stuff
EOT
      parsed = <<EOT
This is some template that's cool and stuff

This is the other template

And the rest of the stuff
EOT
      Template.render(source).should == parsed
    end
    it "should support nested includes" do
      source = <<EOT
This is the template of your dreams

[include 'another']

And the dragon comes in the NIIIGHHHHTTTT
EOT
      parsed = <<EOT
This is the template of your dreams

This is another template This is yours templates This be mine template

And the dragon comes in the NIIIGHHHHTTTT
EOT
      Template.render(source).should == parsed
    end
    it "should not replace an [include] sub which attempts to include itself" do
      source = "[include 'self-referential']"
      parsed = "[include 'self-referential']"
      Template.render(source).should == parsed
    end
    it "should not replace an [include] sub which attempts to include itself, from inside another sub's arg list" do
      source = "[include self-referential-within-args]"
      parsed = "Jim [include self-referential-within-args]ed the bar"
      Template.render(source, :custom_command_class => CustomCommands).should == parsed
    end
  end
  
  describe "when parsing custom block commands" do
    it "should correctly parse a block command" do
      source = <<-EOT
[reverse_lines]Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
Morbi commodo, ipsum sed pharetra gravida,
 orci magna rhoncus neque,
 id pulvinar odio lorem non turpis.
Nullam sit amet enim.[/reverse_lines]
EOT
      parsed = <<-EOT
Nullam sit amet enim.
 id pulvinar odio lorem non turpis.
 orci magna rhoncus neque,
Morbi commodo, ipsum sed pharetra gravida,
Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
EOT
      Template.render(source, :custom_command_class => CustomCommands).should == parsed
    end
    
    it "should correctly parsed nested block commands" do
      source = <<-EOT
[straight][reverse_lines]Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
Morbi commodo, ipsum sed pharetra gravida,
 orci magna rhoncus neque,
 id pulvinar odio lorem non turpis.
Nullam sit amet enim.[/reverse_lines][/straight]
EOT
      parsed = <<-EOT
Nullam sit amet enim.
 id pulvinar odio lorem non turpis.
 orci magna rhoncus neque,
Morbi commodo, ipsum sed pharetra gravida,
Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
EOT
    end
    
    it "should autoclose any block commands that aren't closed by the end of the string" do
      source = <<-EOT
[straight][reverse_lines]Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
Morbi commodo, ipsum sed pharetra gravida,
 orci magna rhoncus neque,
 id pulvinar odio lorem non turpis.
Nullam sit amet enim.
EOT
      parsed = "Nullam sit amet enim.
 id pulvinar odio lorem non turpis.
 orci magna rhoncus neque,
Morbi commodo, ipsum sed pharetra gravida,
Lorem ipsum dolor sit amet, consectetuer adipiscing elit."
      Template.render(source, :custom_command_class => CustomCommands).should == parsed
    end
    
    it "should not rollback a block command if the syntax of the closing sub is not correct, but treat it as if it was never closed" do
      source = "blah [reverse]lorem ipsum dolor sit amet[/ reverse] some more"
      parsed = "blah erom emos ]esrever /[tema tis rolod muspi merol"
      Template.render(source, :custom_command_class => CustomCommands).should == parsed
    end
  end
  
  describe "when parsing subs where the name is a sub" do
    it "should not crash when the outer sub does not exist" do
      Template.render("[[foo] bar]", :vars => {"foo" => "bar"}).should == "[bar bar]"
    end
    it "should not crash when the outer sub does exist" do
      Template.render("[[foo] zing zang zoom]", :vars => {"foo" => "sproink"}, :custom_command_class => CustomCommands).should == "zoom zang zing"
    end
    it "should work for an unlimited number of surrounding brackets" do
      Template.render("[[[[[[foo]]]]]]", :vars => {"foo" => "bar"}).should == "[[[[[bar]]]]]"
    end
  end
  
end
