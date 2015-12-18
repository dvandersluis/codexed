module Papyrus
  # A Template is the grand central station of the parsing process. It represents
  # a source string that will be tokenized, parsed, and evaluated into a final string.
  # Essentially, when a template is rendered, any substitutions (bits of code surrounded
  # by square brackets, such as [foo] or [bar 1 2 3]) in the source string are executed
  # and then replaced with their resulting values.
  class Template

    class << self
      # Parses the substitutions in the source string and replaces them with their
      # corresponding values. The replacement text of [body] subs are specially
      # processed if so specified. Returns the final string.
      def render(content, options = {})
        new(content, options).render
      end
    end
    
    attr_reader :options, :content, :tokenizer, :parser
    attr_reader :vars, :custom_commands, :shielded_commands
    attr_accessor :parent, :allowed_commands
    
    delegate :[], :[]=, :to => :@vars
    
    # Creates a new Template, storing the given content and options.
    # Content is usually a string, but may also be an instance of StringScanner.
    # Available options are:
    #
    # * <tt>:vars</tt> - Template variables which will be set in the created document before it is parsed
    # * <tt>:custom_command_class</tt> - If you have a set of custom commands, and you want Papyrus to use
    #   it when resolving subs, you can pass the class here (as a constant, not a string).
    # * <tt>:shielded_commands</tt> - An array of command names that will be "shielded" - i.e., if there
    #   are any subs passed as arguments to these commands, they will be ignored instead of being replaced.
    # * <tt>:allowed_commands</tt> - An array of command names. Only these commands will be replaced,
    #   all other ones will be ignored.
    # * <tt>:extra</tt> - Right now these options are used to determine whether the parsed content
    #   should be post-processed, and they are also are also passed to your CustomCommandSet.
    #
    # All options above will also be used by the Parser and Tokenizer, created later in the
    # parsing process.
    def initialize(content, options={})
      self.content = content
      @options = options
      @vars = (@options[:vars] ||= {})
      if @options[:custom_command_class]
        @options[:custom_commands] = @options[:custom_command_class].new(self, @options[:extra])
      end
      @custom_commands = @options[:custom_commands]
      @shielded_commands = (@options[:shielded_commands] ||= [])
      @allowed_commands = @options[:allowed_commands]
    end
    
    # Called on #dup or #clone.
    def initialize_copy(template)
      @options = @options.clone
      @options[:vars] = @vars = @vars.deep_copy
      if @custom_commands
        @custom_commands = @options[:custom_commands] = @custom_commands.clone
      end
      @shielded_commands = @options[:shielded_commands] = @shielded_commands.clone
      if @allowed_commands
        @allowed_commands = @options[:allowed_commands] = @allowed_commands.clone
      end
      if @parser
        @parser = @parser.clone
        @parser.template = self
      end
    end
    
    # Runs the content through the tokenizer to produce an array of tokens, then
    # runs those tokens through the parser to produce a document of nodes.
    # Returns the resulting document.
    def analyze
      tokenize
      parse
    end
    
    # Parses the substitutions in the source string and replaces them with their
    # corresponding values. The replacement text of [body] subs are specially
    # processed if so specified. Returns the final string.
    def render
      analyze
      evaluate
      process_bodies if @options[:extra] && @options[:extra][:process_body]
      return @results.join
    end
    
    # Ensures that the given content is stored as a StringScanner, which provides
    # useful methods for stepping through the content.
    def content=(content)
      @content = content.is_a?(StringScanner) ? content : StringScanner.new(content)
      @tokenizer = @parser = @results = nil
    end

    # Clones the current template, allowing you to specify new content, options,
    # or parent. Note that you can keep the old options if you like by just passing
    # an empty hash - this will simply merge the new ones into the old.
    def clone_with(content, options={}, parent=nil)
      template = self.clone
      template.content = content
      template.options.deep_merge!(options)
      template.parent = parent if parent
      template
    end
    
    def template
      self
    end
    
    #def inspect
    #  "#<%s:0x%x %s>" % [ self.class, self.object_id, @content.inspect ]
    #end
    def pretty_print_instance_variables
      ["@content", "@options"]
    end
    
  private
    def tokenize
      @tokenizer = Tokenizer.new(self)
      @tokenizer.tokenize
    end
    
    def parse
      @parser = Parser.new(self)
      @parser.parse
    end
  
    def evaluate
      @results = @parser.document.evaluate
      @results
    end
    
    def process_bodies
      @results.each_with_index do |str, i|
        next unless BodyString === str
        @results[i] = @options[:extra][:process_body].call(str)
      end
    end
    
  end
end
