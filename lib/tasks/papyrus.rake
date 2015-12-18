$LOAD_PATH.unshift("#{RAILS_ROOT}/lib/papyrus")
RAILS_ENV = 'rake'
require 'papyrus'

namespace :papyrus do
  desc "Find objects needing inline-to-block conversion"
  task :fix_invalid_inline_subs => :environment do
    objects = Template.all(:conditions => "raw_content LIKE '%[locked %' OR raw_content LIKE '%[page %' OR raw_content LIKE '%[entry %'") +
      Post.all(:conditions => "raw_body LIKE '%[locked %' OR raw_body LIKE '%[page %' OR raw_body LIKE '%[entry %'")
    
    objects.each do |obj|
      convert_subs(obj)
    end
  end

  desc "Convert an inline versions of [entry], [page] and [locked] subs to block subs for a given Post or Template"
  task :convert_inline_to_block => :environment do
    post_id = ENV["POST_ID"]
    template_id = ENV["TEMPLATE_ID"]

    if post_id.nil? and template_id.nil?
      puts "papyrus:convert_inline_to_block requires either a post or template ID to work on."
      exit
    end

    obj = !post_id.nil? ? Post.find(post_id) : Template.find(template_id)
    convert_subs(obj)
  end
end

def convert_subs(obj)
  print "Processing #{obj.class} ##{obj.id}... "

  content = obj.raw_content || obj.raw_body

  # Send the content to Papyrus to be tokenized
  template = Papyrus::Template.new(content)
  stack = template.send(:tokenize)

  # Get the tokens which are TokenLists (ie. subs) and rewrite them as necessary
  tokenlists = stack.select{|s| s.is_a? Papyrus::TokenList}
  traverse_tokenlist(tokenlists) do |tl|
    if %w(entry page locked).include? tl[1].to_s
      rewrite_inline_to_block(tl)
    end
  end

  # Put the content back together
  new_content = stack.join

  # Save if something's changed
  if new_content != content
    # Backup the previous version
    backup_dir = obj.journal.user.userspace_dir / 'backup'
    Dir.mkdir backup_dir  unless File.exists? backup_dir
    File.open(backup_dir / (obj.is_a?(Post) ? "post_#{obj.id}.bak" : "template_#{obj.id}.bak"), 'w') do |f|
      f.write content
    end

    # Save the object
    if obj.is_a? Template
      obj.raw_content = new_content
    else
      obj.raw_body = new_content
    end
    obj.save
    puts "Saved."
  else
    puts "No change."
  end
end

def traverse_tokenlist(tokenlists, &block)
  tokenlists.each do |t|
    yield t if block_given?

    if (subs = t.select{ |token| token.is_a? Papyrus::TokenList }).size
      traverse_tokenlist(subs, &block)
    end
  end
end

def rewrite_inline_to_block(tokens)
  # If it looks like a block tag already, skip
  return if tokens[1] === Papyrus::Token::Slash or tokens.select{|m| !m.is_a? Papyrus::Token::Whitespace}.count == 3

  # Close the new block start tag
  tokens[2,0] = Papyrus::Token::RightBracket.new

  # Remove leading whitespace and quotes
  leading_quote = false
  while true do
    case 
      when tokens[3].is_a?(Papyrus::Token::Whitespace) then tokens.delete_at 3
      when tokens[3].is_a?(Papyrus::Token::SingleQuote), tokens[3].is_a?(Papyrus::Token::DoubleQuote) then
        leading_quote = true
        tokens.delete_at 3
        break
      else break
    end
  end

  # Remove trailing whitespace and quotes
  while true do
    case 
      when tokens[-2].is_a?(Papyrus::Token::Whitespace) then tokens.delete_at -2
      when tokens[-2].is_a?(Papyrus::Token::SingleQuote), tokens[-2].is_a?(Papyrus::Token::DoubleQuote) then
        tokens.delete_at -2 if leading_quote
        break
      else break
    end
  end

  # Add new block end tag
  tokens[-1,1] = tokens[0..2]
  tokens[-2] = Papyrus::Token::Text.new "/" + tokens[-2].to_s
end
