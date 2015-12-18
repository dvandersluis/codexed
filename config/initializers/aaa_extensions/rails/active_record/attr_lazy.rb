# Provides the ability to specify attributes that will not be loaded when the record
# is initialized from the database, until you explicitly refer to those attributes.
# Adapted from:
# <http://refactormycode.com/codes/219-activerecord-lazy-attribute-loading-plugin-for-rails>
module AttrLazy
  def self.included(klass)
    (class << klass; self; end).class_eval do
      include ClassMethods
      alias_method :find_including_lazy_attributes, :find
      alias_method :find, :find_excluding_lazy_attributes
    end
  end
  
  module ClassMethods
    def attr_lazy_columns
      @attr_lazy_columns ||= []
    end
    
    def attr_lazy(*args)
      args = [args].flatten.map(&:to_s)
      new_cols = args - (attr_lazy_columns & args)
      @attr_lazy_columns |= args
      new_cols.each do |col|
        class_eval("def #{col}; read_lazy_attribute :#{col}; end", __FILE__, __LINE__)
      end
    end
    
    def unlazy_column_names
      column_names - attr_lazy_columns
    end
    
    def read_lazy_attribute(record, attr)
      # we use with_exclusive_scope here to override any :includes that may have happened in a parent scope
      with_exclusive_scope(:find => { :select => [primary_key, attr].join(",") }) do
        find_including_lazy_attributes(record[primary_key])[attr]
      end
    end
    
    def find_excluding_lazy_attributes(*args)
      # don't limit :select clause if there aren't any lazy attributes defined on this model
      # or we're inside a scope right now that has already defined :select
      if attr_lazy_columns.empty? or (scope = scope(:find) and scope[:select])
        find_including_lazy_attributes(*args)
      else
        with_scope(:find => { :select => unlazy_column_list }) do
          find_including_lazy_attributes(*args)
        end
      end
    end
    
  private
    def unlazy_column_list
      unlazy_column_names.map {|c| "#{quoted_table_name}.#{connection.quote_column_name(c)}" }.join(",")
    end
  end
  
private
  def read_lazy_attribute(attr)
    attr = attr.to_s
    unless @attributes.include?(attr)
      @attributes[attr] = self.class.read_lazy_attribute(self, attr)
    end
    @attributes[attr]
  end
end

class ActiveRecord::Associations::ClassMethods::JoinDependency::JoinBase
  # Override to use unlazy_column_names instead of just column_names
  def column_names_with_alias
    unless defined?(@column_names_with_alias)
      @column_names_with_alias = []
      ([active_record.primary_key] + (active_record.unlazy_column_names - [active_record.primary_key])).each_with_index do |column_name, i|
        @column_names_with_alias << [column_name, "#{ aliased_prefix }_r#{ i }"]
      end
    end
    @column_names_with_alias
  end
end

ActiveRecord::Base.class_eval { include AttrLazy }