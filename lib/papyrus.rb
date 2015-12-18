$LOAD_PATH.unshift File.dirname(__FILE__)

# Papyrus is the template engine that powers Codexed. It was originally adapted from
# PageTemplate but was also indirectly inspired by Liquid.
#
# Author: Elliot Winkler
#
module Papyrus
  class ParserError               < ::StandardError ; end
  class UnmatchedLeftBracketError < ParserError     ; end
  class UnmatchedSingleQuoteError < ParserError     ; end
  class UnmatchedDoubleQuoteError < ParserError     ; end
  class MisplacedQuoteError       < ParserError     ; end
  class UnknownSubError           < ParserError     ; end
  class ArgumentError             < ParserError     ; end
  class UnknownVariableError      < ParserError     ; end
  class InvalidCloseSubError      < ParserError     ; end
  class UnmatchedCloseSubError    < ParserError     ; end
  class RedoEvaluation            < ::StandardError ; end  # more like a flow control thingy, but whatever
  
  class << self
    def debug(str=nil)
      if defined?(RAILS_DEFAULT_LOGGER)
        RAILS_DEFAULT_LOGGER.debug(str)
      else
        puts str
      end
    end
  end
end

# Fix StringScanner so that StringScanner.new("foo") == StringScanner.new("foo")
class StringScanner
  def ==(other)
    StringScanner === other && self.string == other.string
  end
end

if defined?(RAILS_ENV)
  if %w(test rake).include? RAILS_ENV
    require 'papyrus/context_item'
    require 'papyrus/context'
  
    require 'papyrus/node'
    require 'papyrus/node_list'
    require 'papyrus/sub'
    require 'papyrus/text'
  
    require 'papyrus/inline_sub'
  
    require 'papyrus/command'
    require 'papyrus/block_command'
    require 'papyrus/custom_block_command'
  
    require 'papyrus/insertion_sub'
    require 'papyrus/variable'
  
    require 'papyrus/custom_command_set'
  
    require 'papyrus/lexicon'
    Dir[File.dirname(__FILE__)+'/papyrus/commands/*.rb'].each {|x| require x }
  
    require 'papyrus/document'
    require 'papyrus/token'
    require 'papyrus/token_list'
    require 'papyrus/tokenizer'
    require 'papyrus/parser'
    require 'papyrus/template'
  else
    Papyrus::Text
    Papyrus::Lexicon.extend_lexicon(Papyrus::Commands)
  end
end

module Papyrus
  class BodyString < String
    def inspect
      "BodyString(#{super})"
    end
  end
  class SeparateString < String
    def inspect
      "SeparateString(#{super})"
    end
  end
  
  class BodyNodeList < NodeList; end
end
