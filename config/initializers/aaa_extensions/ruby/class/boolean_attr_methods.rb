class Class
  def boolean_attr_reader(*attrs)
    attrs.flatten.each do |attr|
      class_eval <<-EOT, __FILE__, __LINE__
        def #{attr}
          @#{attr}.to_b
        end
        alias_method :#{attr}?, :#{attr}
      EOT
    end
  end
  def boolean_attr_writer(*attrs)
    attr_writer *attrs
  end
  def boolean_attr_accessor(*attrs)
    boolean_attr_reader *attrs
    boolean_attr_writer *attrs
  end
end