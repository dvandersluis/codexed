module Papyrus
  # An InsertionSub is a special sub whose #evaluate method, instead of returning
  # the value of the sub, takes the value, runs it through the Parser, and inserts
  # the nodes into the parent NodeList. This allows whatever's inside of the sub
  # to be evaluated as well -- as the the Parser is iterating through the Document!
  module InsertionSub
    def parse_and_insert_into_parent(content)
      return "" if content.blank?
      
      template = self.template.clone_with(content, {}, self)
      document = template.analyze
      
      # don't bother re-parsing this content if it has been evaluated as much as it can be
      # but evaluate this here in case the content contains a backslashed sub
      return document.evaluate.join if document.nodes.all? {|node| Text === node }
      
      klass = (Variable === self && @name == "body") ? BodyNodeList : NodeList
      self.parent.expand_current(document.nodes, klass)
      raise RedoEvaluation
    end
  end
end