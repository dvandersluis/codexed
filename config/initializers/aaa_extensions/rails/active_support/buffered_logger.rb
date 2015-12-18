ActiveSupport::BufferedLogger.class_eval do
  def add_without_newline(severity, message = nil, progname = nil, &block)
    return if @level > severity
    message = (message || (block && block.call) || progname).to_s
    buffer << message
    auto_flush
    message
  end
end