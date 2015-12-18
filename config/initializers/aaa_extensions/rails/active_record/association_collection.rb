module ActiveRecord
  module Associations
    class AssociationCollection
      protected
        # Override method_missing to check scopes before passing the method along.
        # This allows for named scopes with names that are Enumerable methods
        def method_missing(method, *args)
          if @reflection.klass.scopes.include?(method)
            @reflection.klass.scopes[method].call(self, *args)
          elsif @target.respond_to?(method) || (!@reflection.klass.respond_to?(method) && Class.respond_to?(method))
            if block_given?
              super { |*block_args| yield(*block_args) }
            else
              super
            end
          else          
            with_scope(construct_scope) do
              if block_given?
                @reflection.klass.send(method, *args) { |*block_args| yield(*block_args) }
              else
                @reflection.klass.send(method, *args)
              end
            end
          end
        end
    end
  end
end
