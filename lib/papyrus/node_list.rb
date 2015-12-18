module Papyrus
  # A NodeList is an Array-like object that serves as a container for nodes during
  # the tokenizing/parsing process. It is used to hold all the top-level nodes, as
  # well as arguments for subs. As it is a Node itself, it has a parent and can be evaluated.
  class NodeList < Node
    # Array-like features
    delegate :length, :size, :first, :last, :empty?, :shift, :map, :map!, :clear, :each, :include?, :delete, :to => :@nodes
    
    attr_reader :nodes, :orig_nodes
    
    # Creates a new NodeList. If an array is given it will be used as values of the list.
    def initialize(*args)
      @nodes = args.first || []
      @nodes = @nodes.nodes if @nodes.respond_to?(:nodes)
      @nodes.each {|node| node.parent = self }
    end
    
    # Called on #dup or #clone.
    def initialize_copy(list)
      @nodes = @nodes.map {|node| node2 = node.clone; node2.parent = self; node2 }
    end

    # Adds the given node to the NodeList. The parent of the Node is automatically
    # set to this NodeList.
    #
    # A TypeError is raised if the object being added is not a Node.
    #
    # Note: This is also aliased as <<
    def add(node)
      return unless node
      raise TypeError, "NodeList#add: Expected a Node, got a #{node.class} = #{node.inspect}" unless Node === node
      @nodes << node
      node.parent = self
      self
    end
    def <<(node)
      add(node)
    end

    # Evaluates all the nodes in the node list and returns a string of the results.
    # This string will actually be a BodyString, if we are evaluating the resulting
    # node list of a [body] sub (this is so we can process the body later).
    def evaluate
      arr = []
      laststr = nil
      evaluated_nodes.each do |str|
        if arr.empty? || SeparateString === str || SeparateString === laststr || BodyString === str || BodyString === laststr
          if BodyString === str
            arr << str
          elsif SeparateString === str
            arr << String.new(str)
          elsif BodyNodeList === self
            arr << BodyString.new(str)
          else
            arr << str
          end
        else
          arr.last << str
        end
        laststr = str
      end
      arr
    end
    
    # Evaluates all the nodes in the node list and returns an array of either strings
    # or BodyStrings.
    def to_a
      evaluated_nodes
    end
    
    # Assuming that this node list is currently being iterated over, takes whatever
    # node the iterator is on and replaces it with the given document. The nodes within
    # the document are re-wrapped in a node list you specify. This is used by
    # [include] as well as [body] and other variables.
    #
    # Note that this method destructively modifies the nodes inside the given
    # document (by realigning parent pointers). This should be okay, however, since
    # we're assuming the document is temporary anyway.
    def expand_current(nodes, klass)
      nodes.each {|node| node.old_parent = node.parent }
      list = klass.new(nodes)
      list.parent = self
      @nodes[@pos] = list
    end
    
    # Collapses the NodeList into a one-dimensional list. Based off Rubinius code.
    def flatten
      out = []
      recursively_flatten_to!(out, self)
      list = NodeList.new(out)
      list.parent = self.parent
      list
    end
    
    # for testing
    def ==(other)
      other.is_a?(self.class) &&
      @nodes == other.nodes
    end
    
    def pretty_print_instance_variables
      %w(@nodes)
    end
    
  private
    def evaluated_nodes
      # back this up in case we need it, as the node list may get manipulated
      @orig_nodes ||= @nodes.clone
      arr = []
      @pos = 0
      i = 0
      while @pos < @nodes.size
        node = @nodes[@pos]
        result = nil
        if node.respond_to?(:insertion_doppelganger) && node == node.insertion_doppelganger
          #   2015 JENNIFER: "I'm young!"
          #   1985 JENNIFER (simultaneously): "I'm old!"
          #
          # Great Scott! We must be trying to evaluate a node that we've already seen in a past
          # timeline! Since evaluating this node would create a cataclysmic unravel-the-fabric-
          # of-the-spacetime-continuum paradox kind of thing (alright, fine, an infinite loop),
          # don't bother evaluating this sub, and roll back to the sub that created this paradox.
          result = node.insertion_doppelganger.raw_sub
        else
          begin
            result = node.evaluate
          rescue RedoEvaluation
            i += 1
            raise "Infinite loop" if i == 50
            next
          end
        end
        raise "A node evaluates to nil!\n#{node.pretty_inspect}" unless result
        i = 0
        # node lists will evaluate to arrays, everything else will evaluate to strings
        if Array === result
          arr += result
        else
          arr << result
        end
        @pos += 1
      end
      arr
    end
    
    def recursively_flatten_to!(out, array)
      # go through the array and extract the non-array items into a separate array,
      # descending into sub-arrays
      array.each do |o|
        if NodeList === o
          recursively_flatten_to!(out, o.nodes)
        elsif o.respond_to?(:to_ary)
          ary = Array === o ? o : o.to_ary
          recursively_flatten_to!(out, ary)
        else
          out << o
        end
      end
    end

  end
end