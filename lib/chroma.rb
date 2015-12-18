require 'rubygems'
require 'term/ansicolor'

Color = Term::ANSIColor

module Kernel
  class ColorLoggerAppender
    def self.next_instance(caller)
      file, line, full_method, object_name = caller
      color, i = Chroma.get_color_for_key(object_name, true)
      is_bold = (i % 2) == 1
      new(color, is_bold, caller)
    end
    
    attr_reader :color, :caller
    def bold?; @is_bold; end
    
    def initialize(color, is_bold, caller)
      @color = color
      @is_bold = is_bold
      @caller = caller
    end
    
    def <<(msg)
      msg = Chroma.colorize(@color, @is_bold, msg)
      RAILS_DEFAULT_LOGGER.add_without_newline(ActiveSupport::BufferedLogger::DEBUG, msg)
    end
  end
  
  # pplc backtrace_info, :foo => :bar
  # pplc bt, :foo => :bar
  def pplc(caller, *objs)
    appender = ColorLoggerAppender.next_instance(caller)
    
    file, line, full_method, object_name = caller
    whereabouts = "#{full_method} @ #{file}:#{line}"
    str = ("-" * whereabouts.length) + "\n" + whereabouts + "\n" + ("-" * whereabouts.length) + "\n"
    appender << str
    
    objs.each {|obj|
      PP.pp(obj, appender)
    }
    nil
  end
  module_function :pplc
  
  def log_with_color(caller, header, body)
    file, line, full_method, object_name = caller
    color, i = Chroma.get_color_for_key(object_name, true)
    is_bold = (i % 2) == 1
    
    whereabouts = "#{full_method} @ #{file}:#{line}"
    
    str = ""
    str << ("-" * (50 + whereabouts.length)) + "\n"
    str << header.ljust(50, " ") + whereabouts + "\n"
    str << ("-" * (50 + whereabouts.length)) + "\n"
    str << body
    
    RAILS_DEFAULT_LOGGER.debug Chroma.colorize(color, is_bold, str)
  end
  alias_method :lc, :log_with_color
  module_function :log_with_color
  
  def colorize(color, is_bold, msg)
    Chroma.colorize(color, is_bold, msg)
  end
  module_function :colorize
  
  def caller_pieces(backtrace_line_or_level)
    backtrace_line = (Fixnum === backtrace_line_or_level) ? caller[backtrace_line_or_level] : backtrace_line_or_level
    md = backtrace_line.match(/^([^:]+):(\d+)(?:\:in `([^']+)')?$/)
    file, line, method = md.captures
    pwd = `pwd`.chomp + "/"
    until pwd.empty?
      file.sub!(%r|^#{pwd}|, "") and break
      pwd.sub!(%r|([^/]+)/$|, "") or break
    end
    [file, line, method]
  end
  module_function :caller_pieces

  def backtrace_info(frame=0)
    backtrace = caller(frame+1)
    file, line, method = caller_pieces(backtrace[0])
    indent_level = backtrace.size
    if method
      object_id = "0x%x" % (self.object_id * 2)
      # thanks to
      # http://www.phwinfo.com/forum/comp-lang-ruby/358098-getting-current-module-s-class-name-method-ruby-1-9-a.html
      if self.class == Class || self.class == Module
        object_name = "#{self.to_s}-#{object_id}"
        full_method = "#{object_name}.#{method}"
      else
        object_name = "#{self.class}-#{object_id}"
        full_method = "#{object_name}##{method}"
      end
    end
    [file, line, full_method, object_name, indent_level]
  end
  alias_method :bt, :backtrace_info
  module_function :backtrace_info
end

class Chroma
  class << self
    def used_colors
      Thread.current["chroma_used_colors"] ||= {}
    end
    def curr_index
      Thread.current["chroma_curr_index"] ||= -1
    end
    def curr_index=(idx)
      Thread.current["chroma_curr_index"] = idx
    end
    
    def colors
      %w(red green yellow magenta cyan)
    end
  
    def get_color_for_key(key, return_with_index=false)
      used_colors[key] ||= next_color
      return_with_index ? used_colors[key] : used_colors[key][0]
    end
    
    def colorize_by_key(key, str)
      color, i = get_color_for_key(key, true)
      is_bold = (i % 2) == 1
      colorize(color, is_bold, str)
    end
    
    def colorize(color, is_bold, str)
      str = Color.send(color, str)
      str = Color.bold(str) if is_bold
      str
    end
    
  private
    def adjusted_color_index(i)
      i % colors.size
    end
  
    def next_color
      self.curr_index += 1
      i = adjusted_color_index(curr_index)
      [ colors[i], i ]
    end
  end
end