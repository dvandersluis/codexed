class Template
  class Formatting
    
    # taken from <http://kev.coolcavemen.com/2007/03/ultimate-regular-expression-for-html-tag-parsing-with-php/>
    HTML_REGEX = /<(\/)?(\w+)(?:(?:\s+(?:\w|\w[\w-]*\w)(?:\s*=\s*(?:\".*?\"|'.*?'|[^'\">\s]+))?)+\s*|\s*)\/?>/i
    FORMAT_REGEX = /\G(.*?)(\s*#{HTML_REGEX}\s*)/im
    
    RULES = {
      :apply_typographical_effects => lambda { @options.typographical? },
      :apply_linebreak_formatting  => lambda { @options.dnl2p? or @options.nl2br? },
      :apply_text_styles           => lambda { @options.inline? },
      :apply_parentheses_styles    => lambda { @options.parens }
    }
    DEFAULT_METHODS = [:apply_typographical_effects, :apply_linebreak_formatting, :apply_text_styles, :apply_parentheses_styles]
    
    def self.format(content, options, methods=nil)
      new(content, options, methods).format
    end
    
    def initialize(content=nil, options=nil, methods=nil)
      @content = (content || "").dup
      @options = options || OpenHash.new
      
      @methods = methods ? Array(methods) : DEFAULT_METHODS
      @methods = @methods.inject([]) do |methods, method|
        rule = RULES[method]
        methods << method if !rule || instance_eval(&rule)
        methods
      end
      @methods << :unescape_escaped_chars
      @methods.uniq!
      
      @open_tags = []
    end
    
    def format
      return process_text(:text, @content)
      
      #### THE FOLLOWING IS NOT QUITE BULLET-PROOF AND NEEDS TO BE TESTED FURTHER ####
      
      return @content if @content.empty?
      out = ""
      @content.scan(FORMAT_REGEX) do |pre_tag, tag, slash, tag_name|
        match = Regexp.last_match
        if slash
          out << handle_close_tag(pre_tag, tag, tag_name)
        else
          out << handle_open_tag(pre_tag, tag, tag_name)
        end
      end
      match = Regexp.last_match
      if match.nil?
        # this text doesn't actually contain any HTML tags, it seems, so run through as normal
        return process_text(:text, @content)
      end
      if trailing = @content[match.end(0)..-1] and !trailing.blank?
        # some text was found after the last HTML tag
        out << process_text(:text, trailing)
      end
      out
    end
    
    def apply_linebreak_formatting(text)
      return "" if text =~ /\A\s*\Z/
      
      # remove front and end whitespace as it will be replaced with an empty paragraph
      pre = text.slice!(/\A\s*/)
      post = text.slice!(/\s*\Z/)
      
      text.gsub!(/\r\n/, "\n")
      text.gsub!(/\n{2,}/, "</p>\e010\e010<p>") if @options.dnl2p?
      text.gsub!(/\n/, "<br/>\n") if @options.nl2br?
      text = "<p>#{text}</p>" if @options.dnl2p?
      
      pre + text + post
    end
    
    def apply_text_styles(text)
      text.gsub!(/\*\*([^\n]+?)\*\*/, '<b>\1</b>')
      text.gsub!(/\\\\([^\n]+?)\\\\/, '<i>\1</i>')
      text.gsub!(/\_\_([^\n]+?)\_\_/, '<u>\1</u>')
      text
    end
    
    def apply_parentheses_styles(text)
      text = text.gsub(%r|\\\(|, "\e040").gsub(%r|\\\)|, "\e041")
      case @options.parens
      when 'color'
        color = @options.parencolor
        color = '#'+color if color =~ /^[0-9a-f]{3}([0-9a-f]{3})?$/i
        text.gsub!(%r|\(([^\)]+?)\)|, %|<span style="color: #{color}">\e040\\1\e041</span>|)
      when 'class'
        text.gsub!(%r|\(([^\)]+?)\)|, %|<span class="#{@options.parenclass}">\e040\\1\e041</span>|)
      end
      text
    end
    
    def apply_typographical_effects(text)
      # escape quotes that are in HTML tags
      text.gsub!(%r|(<[^>"'-]+)((?:["'-][^'"<>-]*?)*)([^<'"-]*>)|) do
        "%1$s%3$s%2$s" % [$1, $3, $2.gsub(/(["'-])/) {"\e%.3d" % $1.ord}]
      end

      # TODO: Improve smartquotes algorithm
      
      # translate left quotes that are after whitespace
      text = text.gsub(/(^|\s)"/, '\1“').gsub(/(^|\s)'/, '\1‘')
      # translate right quotes
      text = text.gsub('"', "”").gsub("'", "’")

      # let's do ellipses too
      text = text.gsub("...", '…').gsub(". . .", "…")
      # and em dashes
      text.gsub!("--", '—')

      text
    end
    
  private
    def handle_open_tag(pre_tag, tag, tag_name)
      out = ""
      out << handle_pre_tag(pre_tag) unless pre_tag.blank?
      out << tag
      @open_tags << tag_name
      out
    end
    
    def handle_close_tag(pre_tag, tag, tag_name)
      out = ""
      out << handle_pre_tag(pre_tag) unless pre_tag.blank?
      out << tag
      if @open_tags.any? && @open_tags.include?(tag_name)
        # we can't just pop off last tag since tags may not be properly closed
        # (e.g. we may have something like <b><i>...</b></i>)
        # so if a tag's parent is closed before the tag is, treat the tag as closed before closing the parent
        popped = nil
        begin; popped = @open_tags.pop; end until popped == tag_name
      end
      out
    end
    
    def handle_pre_tag(pre_tag)
      if @open_tags.any?
        if (%w(script style pre) & @open_tags).any?
          # disable all formatting inside <script>, <style> and <pre>
          pre_tag
        else
          # since we're inside HTML, do not format line breaks (but do everything else)
          process_text(:html, pre_tag)
        end
      else
        # format as usual
        process_text(:text, pre_tag)
      end
    end
  
    def process_text(type, text)
      methods = @methods
      methods -= [:apply_linebreak_formatting] if type == :html
      # run text through all the formatting methods
      methods.inject(text.dup) {|text, meth| send(meth, text) }
    end
    
    def unescape_escaped_chars(text)
      text.gsub(/\e(\d\d\d)/) { $1.to_i.chr }
    end
  end
end
