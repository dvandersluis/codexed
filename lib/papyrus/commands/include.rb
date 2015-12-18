module Papyrus
  module Commands
    # The Include class represents an [include] sub, which can be used to insert
    # content from another source into the current template.
    class Include < Command
      include InsertionSub
      
      # Returns the content that will be inserted into the current template.
      def get_template_source
        raise NotImplementedError, 'Include#get_template_source must be implemented by a subclass. It should return the template content that will replace [include].'
      end
      
      # Runs the content retrieved by #get_template_source through the parser and
      # inserts the resulting nodes into the document that is currently being
      # evaluated. Returns the evaluated content.
      def evaluate
        @evaluated_args = @args.to_a
        @template_name = @evaluated_args.first
        raise ArgumentError, "Template name was not given" unless @template_name
        returning get_template_source do |content|
          parse_and_insert_into_parent(content)
        end
      end
    end 
  end
end