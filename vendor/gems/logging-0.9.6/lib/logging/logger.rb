
module Logging

  # The +Logger+ class is the primary interface to the +Logging+ framework.
  # It provides the logging methods that will be called from user methods,
  # and it generates logging events that are sent to the appenders (the
  # appenders take care of sending the log events to the logging
  # destinations -- files, sockets, etc).
  #
  # +Logger+ instances are obtained from the +Repository+ and should
  # not be directly created by users.
  #
  # Example:
  #
  #    log = Logging::Logger['my logger']
  #    log.add_appenders( Logging::Appender.stdout )   # append to STDOUT
  #    log.level = :info                               # log 'info' and above
  #
  #    log.info 'starting foo operation'
  #    ...
  #    log.info 'finishing foo operation'
  #    ...
  #    log.fatal 'unknown exception', exception
  #
  class Logger

    @mutex = Mutex.new  # :nodoc:

    class << self

      # call-seq:
      #    Logger.root
      #
      # Returns the root logger.
      #
      def root
        ::Logging::Repository.instance[:root]
      end

      # :stopdoc:

      # Overrides the new method such that only one Logger will be created
      # for any given logger name.
      #
      def new( *args )
        return super if args.empty?

        repo = ::Logging::Repository.instance
        name = repo.to_key(args.shift)

        @mutex.synchronize do
          logger = repo[name]
          if logger.nil?
            logger = super(name, *args)
            repo[name] = logger
            repo.children(name).each {|c| c.__send__(:parent=, logger)}
          end
          logger
        end
      end
      alias :[] :new

      # This is where the actual logging methods are defined. Two methods
      # are created for each log level. The first is a query method used to
      # determine if that perticular logging level is enabled. The second is
      # the actual logging method that accepts a list of objects to be
      # logged or a block. If a block is given, then the object returned
      # from the block will be logged.
      #
      # Example
      #
      #    log = Logging::Logger['my logger']
      #    log.level = :warn
      #
      #    log.info?                               # => false
      #    log.warn?                               # => true
      #    log.warn 'this is your last warning'
      #    log.fatal 'I die!', exception
      #
      #    log.debug do
      #      # expensive method to construct log message
      #      msg
      #    end
      #
      def define_log_methods( logger )
        ::Logging::LEVELS.each do |name,num|
          code =  "undef :#{name}  if method_defined? :#{name}\n"
          code << "undef :#{name}? if method_defined? :#{name}?\n"

          if logger.level > num
            code << <<-CODE
              def #{name}?( ) false end
              def #{name}( data = nil ) false end
            CODE
          else
            code << <<-CODE
              def #{name}?( ) true end
              def #{name}( data = nil )
                data = yield if block_given?
                log_event(::Logging::LogEvent.new(@name, #{num}, data, @trace))
                true
              end
            CODE
          end

          logger._meta_eval(code, __FILE__, __LINE__)
        end
        logger
      end
      # :startdoc:

    end  # class << self

    attr_reader :name, :parent, :additive, :trace

    # call-seq:
    #    Logger.new( name )
    #    Logger[name]
    #
    # Returns the logger identified by _name_.
    #
    # When _name_ is a +String+ or a +Symbol+ it will be used "as is" to
    # retrieve the logger. When _name_ is a +Class+ the class name will be
    # used to retrieve the logger. When _name_ is an object the name of the
    # object's class will be used to retrieve the logger.
    #
    # Example:
    #
    #   obj = MyClass.new
    #
    #   log1 = Logger.new(obj)
    #   log2 = Logger.new(MyClass)
    #   log3 = Logger['MyClass']
    #
    #   log1.object_id == log2.object_id         # => true
    #   log2.object_id == log3.object_id         # => true
    #
    def initialize( name )
      case name
      when String
        raise(ArgumentError, "logger must have a name") if name.empty?
      else raise(ArgumentError, "logger name must be a String") end

      repo = ::Logging::Repository.instance
      _setup(name, :parent => repo.parent(name))
    end

    # call-seq:
    #    log <=> other
    #
    # Compares this logger by name to another logger. The normal return codes
    # for +String+ objects apply.
    #
    def <=>( other )
      case other
      when self; 0
      when ::Logging::RootLogger; 1
      when ::Logging::Logger; @name <=> other.name
      else raise ArgumentError, 'expecting a Logger instance' end
    end

    # call-seq:
    #    log << "message"
    #
    # Log the given message without any formatting and without performing any
    # level checks. The message is logged to all appenders. The message is
    # passed up the logger tree if this logger's additivity is +true+.
    #
    def <<( msg )
      @appenders.each {|a| a << msg}
      @parent << msg if @additive
    end

    # call-seq:
    #    add( severity, message = nil ) {block}
    #
    # Log a message if the given severity is high enough.  This is the generic
    # logging method.  Users will be more inclined to use #debug, #info, #warn,
    # #error, and #fatal.
    #
    # <b>Message format</b>: +message+ can be any object, but it has to be
    # converted to a String in order to log it. The Logging::format_as
    # method is used to determine how objects chould be converted to
    # strings. Generally, +inspect+ is used.
    #
    # A special case is an +Exception+ object, which will be printed in
    # detail, including message, class, and backtrace.
    #
    # If a _message_ is not given, then the return value from the block is
    # used as the message to log. This is useful when creating the actual
    # message is an expensive operation. This allows the logger to check the
    # severity against the configured level before actually constructing the
    # message.
    #
    # This method returns +true+ if the message was logged, and +false+ is
    # returned if the message was not logged.
    #
    def add( lvl, data = nil )
      lvl = Integer(lvl)
      return false if lvl < level

      data = yield if block_given?
      log_event(::Logging::LogEvent.new(@name, lvl, data, @trace))
      true
    end

    # call-seq:
    #    additive = true
    #
    # Sets the additivity of the logger. Acceptable values are +true+,
    # 'true', +false+, 'false', or +nil+. In this case +nil+ does not
    # change the additivity
    #
    def additive=( val )
      @additive = case val
                  when true, 'true'; true
                  when false, 'false'; false
                  when nil; @additive
                  else raise ArgumentError, 'expecting a boolean' end
    end

    # call-seq:
    #    trace = true
    #
    # Sets the tracing of the logger. Acceptable values are +true+,
    # 'true', +false+, 'false', or +nil+. In this case +nil+ does not
    # change the tracing.
    #
    def trace=( val )
      @trace = case val
               when true, 'true'; true
               when false, 'false'; false
               when nil; @trace
               else raise ArgumentError, 'expecting a boolean' end
    end

    # call-seq:
    #    level    => integer
    #
    # Returns an integer which is the defined log level for this logger.
    #
    def level
      return @level unless @level.nil?
      @parent.level
    end

    # call-seq:
    #    level = :all
    #
    # Set the level for this logger. The level can be either a +String+, a
    # +Symbol+, or a +Fixnum+. An +ArgumentError+ is raised if this is not
    # the case.
    #
    # There are two special levels -- "all" and "off". The former will
    # enable log messages from this logger. The latter will disable all log
    # messages from this logger.
    #
    # Setting the logger level to +nil+ will cause the parent's logger level
    # to be used.
    #
    # Example:
    #
    #    log.level = :debug
    #    log.level = "INFO"
    #    log.level = 4
    #    log.level = 'off'
    #    log.level = :all
    #
    # These prodcue an +ArgumentError+
    #
    #    log.level = Object
    #    log.level = -1
    #    log.level = 1_000_000_000_000
    #
    def level=( level )
      @level =
        if level.nil? then level
        else
          lvl = case level
                when String, Symbol; ::Logging::level_num(level)
                when Fixnum; level
                else
                  raise ArgumentError,
                        "level must be a String, Symbol, or Integer"
                end
          if lvl.nil? or lvl < 0 or lvl > ::Logging::LEVELS.length
            raise ArgumentError, "unknown level was given '#{level}'"
          end
          lvl
        end

      define_log_methods(true)
      self.level
    end

    # call-seq:
    #    appenders = app
    #
    # Clears the current list of appenders and replaces them with _app_,
    # where _app_ can be either a single appender or an array of appenders.
    #
    def appenders=( args )
      @appenders.clear
      add_appenders(*args) unless args.nil?
    end

    # call-seq:
    #    add_appenders( appenders )
    #
    # Add the given _appenders_ to the list of appenders, where _appenders_
    # can be either a single appender or an array of appenders.
    #
    def add_appenders( *args )
      args.flatten.each do |arg|
        o = arg.kind_of?(::Logging::Appender) ? arg : ::Logging::Appender[arg]
        raise ArgumentError, "unknown appender '#{arg}'" if o.nil?
        @appenders << o unless @appenders.include?(o)
      end
      self
    end

    # call-seq:
    #    remove_appenders( appenders )
    #
    # Remove the given _appenders_ from the list of appenders. The appenders
    # to remove can be identified either by name using a +String+ or by
    # passing the appender instance. _appenders_ can be a single appender or
    # an array of appenders.
    #
    def remove_appenders( *args )
      args.flatten.each do |arg|
        @appenders.delete_if do |a|
          case arg
          when String; arg == a.name
          when ::Logging::Appender; arg.object_id == a.object_id
          else
            raise ArgumentError, "#{arg.inspect} is not a 'Logging::Appender'"
          end
        end
      end
      self
    end

    # call-seq:
    #    clear_appenders
    #
    # Remove all appenders from this logger.
    #
    def clear_appenders( ) @appenders.clear end

    # call-seq:
    #     inspect    => string
    #
    # Returns a string representation of the logger.
    #
    def inspect
      "<%s:0x%x name=\"%s\">" % [self.class.name, self.object_id, self.name]
    end


    protected

    # call-seq:
    #    parent = ParentLogger
    #
    # Set the parent logger for this logger. This method will be invoked by
    # the +Repository+ class when a parent or child is added to the
    # hierarchy.
    #
    def parent=( parent ) @parent = parent end

    # call-seq:
    #    log_event( event )
    #
    # Send the given _event_ to the appenders for logging, and pass the
    # _event_ up to the parent if additive mode is enabled. The log level has
    # already been checked before this method is called.
    #
    def log_event( event )
      @appenders.each {|a| a.append(event)}
      @parent.log_event(event) if @additive
    end

    # call-seq:
    #    define_log_methods( force = false )
    #
    # Define the logging methods for this logger based on the configured log
    # level. If the level is nil, then we will ask our parent for it's level
    # and define log levels accordingly. The force flag will skip this
    # check.
    #
    # Recursively call this method on all our children loggers.
    #
    def define_log_methods( force = false )
      return if @level and !force

      ::Logging::Logger.define_log_methods(self)
      ::Logging::Repository.instance.children(name).each do |c|
        c.define_log_methods
      end
      self
    end

    # :stopdoc:
    public

    # call-seq:
    #    _meta_eval( code )
    #
    # Evaluates the given string of _code_ if the singleton class of this
    # Logger object.
    #
    def _meta_eval( code, file = nil, line = nil )
      meta = class << self; self end
      meta.class_eval code, file, line
    end

    # call-seq:
    #    _setup( name, opts = {} )
    #
    # Configures internal variables for the logger. This method can be used
    # to avoid storing the logger in the repository.
    # 
    def _setup( name, opts = {} )
      @name      = name
      @parent    = opts.getopt(:parent)
      @appenders = opts.getopt(:appenders, [])
      @additive  = opts.getopt(:additive, true)
      @trace     = opts.getopt(:trace, false)
      @level     = opts.getopt(:level)
      ::Logging::Logger.define_log_methods(self)
    end

    # call-seq:
    #    _dump_configuration( io = STDOUT, indent = 0 )
    #
    # An internal method that is used to dump this logger's configuration to
    # the given _io_ stream. The configuration includes the logger's name,
    # level, additivity, and trace settings. The configured appenders are
    # also printed to the _io_ stream.
    #
    def _dump_configuration( io = STDOUT, indent = 0 )
      str, spacer, base = '', '  ', 50
      indent_str = indent == 0 ? '' : ' ' * indent

      str << indent_str
      str << self.name.reduce(base - indent)
      if (str.length + spacer.length) < base
        str << spacer
        str << '.' * (base - str.length)
      end
      io.write(str.ljust(base))
      io.write(spacer)

      level_str  = @level.nil? ? '' : '*'
      level_str << if level < ::Logging::LEVELS.length
        ::Logging.levelify(::Logging::LNAMES[level])
      else
        'off'
      end
      level_len = ::Logging::MAX_LEVEL_LENGTH + 1

      io.write("%#{level_len}s" % level_str)
      io.write(spacer)

      if self.respond_to?(:additive)
        io.write(additive ? '+A' : '-A')
      else
        io.write('  ')
      end

      io.write(spacer)
      io.write(trace ? '+T' : '-T')
      io.write("\n")

      @appenders.each do |appender|
        io.write(indent_str)
        io.write('- ')
        io.write(appender.inspect)
        io.write("\n")
      end

      return io
    end
    # :startdoc:

  end  # class Logger
end  # module Logging

# EOF
