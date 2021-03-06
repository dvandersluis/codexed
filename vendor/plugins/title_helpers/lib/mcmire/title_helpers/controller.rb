module Mcmire
  module TitleHelpers
    module Controller
      def self.included(base)
        base.class_eval do
          extend ClassMethods
          attr_reader :window_titles
        end
      end
      
      module ClassMethods      
        # Call this in the body of your controller with a string to add the string to
        # the window title before each action in your controller. This will work
        # for subcontrollers too -- so if you call window_title in a supercontroller
        # and also in a subcontroller, there will be two strings when you go to output
        # the window title.
        def window_title(title=nil, &block)
          before_filter do |c|
            c.instance_eval { (@window_titles ||= []) << (block_given? ? block.call : title) }
          end
        end
      
        # Call this in the body of your controller with a string to set the page title
        # globally for each action in your controller. Unlike window_title, this will not
        # work for subcontrollers -- so if you call page_title in a supercontroller and
        # also in a subcontroller, the subcontroller's title will override the supercontroller's.
        def page_title(title=nil, &block)
          before_filter do |c|
            c.instance_eval { @page_title = (block_given? ? block.call : title) }
          end
        end
      
        # Call this in the body of your controller with a string to add it to the
        # window title AND set the page title at the same time.
        # See +window_title+ and +page_title+ for more.
        def title(title=nil, &block)
          window_title(title, &block)
          page_title(title, &block)
        end
      end
    end
  end
end