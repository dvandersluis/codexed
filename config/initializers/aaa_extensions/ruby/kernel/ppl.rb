require 'pp'
module Kernel
  class LoggerAppender
    include Singleton
    def <<(msg)
      RAILS_DEFAULT_LOGGER.add_without_newline(ActiveSupport::BufferedLogger::DEBUG, msg)
    end
  end
  
  # pretty print to Rails log
  def ppl(*objs)
    objs.each {|obj|
      PP.pp(obj, LoggerAppender.instance)
    }
    nil
  end
  module_function :ppl
end