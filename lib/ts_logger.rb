require 'logger'
require 'rubygems'
require 'term/ansicolor'

class TsLogger < Logger

  def format_message(severity, timestamp, progname, msg)
    timefmt = format_time(timestamp)
    strs = msg2str(msg).split(/[\r\n]+/)
    out = ""
    strs.each_with_index do |str, i|
      next if str.strip.blank?
      out << (i == 0 ? Color.bold(timefmt) : timefmt)
      out << "#{str}\n"
    end
    out
  end
private
  def msg2str(msg)
    case msg
    when ::String
      msg
    when ::Exception
      "#{ msg.message } (#{ msg.class }): " <<
      (msg.backtrace || []).join(" | ")
    else
      msg.inspect
    end
  end
  
  def format_time(time)
    Thread.current["first_log_time"] ||= time
    diff = time.to_f - Thread.current["first_log_time"].to_f
    diff_fmt = diff_time(diff)
    "[#{time.strftime("%Y-%m-%d %H:%M:%S")}.#{time.usec.to_s[0...3]}] (#{diff_fmt}) "
  end
  
  def diff_time(diff)
    sec = diff % 60
    diff = (diff - sec) / 60.0
    min =  diff % 60
    prec = get_precision(sec, 3)
    "%02d:%02d.%d" % [min, sec, prec]
  end
  
  def get_precision(number, length)
    number.to_s.split(".")[1].to_s[0...length].to_i
  end

end
