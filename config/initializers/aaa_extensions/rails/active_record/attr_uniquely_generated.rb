module AttrUniquelyGenerated
  def attr_uniquely_generated(*attrs, &block)
    raise "Block must be supplied" unless block_given?
    configuration = attrs.extract_options!
    raise "Callback method must be supplied (one of :save, :create, :update)" unless configuration[:on]
    attrs.flatten.each do |attr|
      callback = "before_#{configuration[:on]}"
      set_method = "generate_#{attr}"
      generate_method = "generated_#{attr}"

      # define the callback
      send(callback, set_method)
      
      # define the methods that the callback will call
      define_method(set_method) do
        self.send("#{attr}=", self.class.send(generate_method))
      end
      self.metaclass.send(:define_method, generate_method) do
        begin; val = block.call; end while exists?(attr => val); val
      end
    end
  end
end

ActiveRecord::Base.class_eval { extend AttrUniquelyGenerated }