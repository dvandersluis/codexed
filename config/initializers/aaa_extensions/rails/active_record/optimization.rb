#module AROptimization
class ActiveRecord::Base
  
  # use each instead of inject, since inject is slow
  def attributes
    attrs = {}; attribute_names.each {|name| attrs[name] = read_attribute(name) }; attrs
  end
  
  # use each instead of inject, since inject is slow
  def attributes_before_type_cast
    attrs = {}; attribute_names.each {|name| attrs[name] = read_attribute_before_type_cast(name) }; attrs
  end
  
  # use each instead of inject, since inject is slow
  def attributes_from_column_definition
    attrs = {}
    for column in self.class.columns
      attrs[column.name] = column.default unless column.name == self.class.primary_key
    end
    attrs
  end
  
  # use each instead of inject, since inject is slow
  def comma_pair_list(hash)
    arr = []; hash.each {|k, v| arr << "#{k} = #{v}" }; arr.join(", ")
  end
  
  # use each instead of inject, since inject is slow
  def quote_columns(quoter, hash)
    quoted = {}
    hash.each {|name, value| quoted[quoter.quote_column_name(name)] = value }
    quoted
  end
  
  # use each instead of inject, since inject is slow
  def clone_attributes(reader_method = :read_attribute, attributes = {})
    for name in attribute_names
      attributes[name] = clone_attribute_value(reader_method, name)
    end
    attributes
  end
  
end